/**
 * CarCards Cloud Functions
 * 
 * Server-side card flattening:
 * - flattenCard: Triggered on Firestore card update (rarity/customFrame change)
 * - batchFlatten: HTTP-callable to re-flatten all cards (e.g., after border redesign)
 * - flattenSingleCard: HTTP-callable to flatten a specific card by ID
 */

const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const sharp = require("sharp");
const path = require("path");
const fs = require("fs");

admin.initializeApp();
const db = admin.firestore();
const storage = admin.storage();

// ─── Border Config ───────────────────────────────────────────────────────────

const BORDER_MAP = {
  "common":    "Border_Common.svg",
  "uncommon":  "Border_Uncommon.png",
  "rare":      "Border_Rare.svg",
  "epic":      "Border_Epic.svg",
  "legendary": "Border_Legendary.svg",
  // Legacy frame names
  "Border_Common":    "Border_Common.svg",
  "Border_Uncommon":  "Border_Uncommon.png",
  "Border_Rare":      "Border_Rare.svg",
  "Border_Epic":      "Border_Epic.svg",
  "Border_Legendary": "Border_Legendary.svg",
  "Border_Def_Wht":   "Border_Def_Wht.png",
};

const DEFAULT_BORDER = "Border_Def_Wht.png";

// Card render dimensions (16:9 landscape)
const CARD_WIDTH = 1920;
const CARD_HEIGHT = 1080;

// ─── Font Loading ────────────────────────────────────────────────────────────

// Load fonts as base64 once at cold start for SVG embedding
let _fontBoldB64 = null;
let _fontLightB64 = null;

function getFontBoldB64() {
  if (!_fontBoldB64) {
    const fontPath = path.join(__dirname, "fonts", "Jost-Bold.ttf");
    if (fs.existsSync(fontPath)) {
      _fontBoldB64 = fs.readFileSync(fontPath).toString("base64");
    }
  }
  return _fontBoldB64;
}

function getFontLightB64() {
  if (!_fontLightB64) {
    const fontPath = path.join(__dirname, "fonts", "Jost-Light.ttf");
    if (fs.existsSync(fontPath)) {
      _fontLightB64 = fs.readFileSync(fontPath).toString("base64");
    }
  }
  return _fontLightB64;
}

// ─── Text Overlay SVG ────────────────────────────────────────────────────────

/**
 * Build an SVG overlay with the card name text.
 * Matches the SwiftUI layout: make (light) + model (bold), top-left with shadow.
 * For driver cards: make (bold) on line 1, year on line 2, model (bold) on line 3.
 */
function buildTextOverlaySVG(cardData) {
  const make = (cardData.make || "").toUpperCase();
  const model = (cardData.model || "").toUpperCase();
  const year = (cardData.year || "").toUpperCase();
  const cardType = cardData.type || cardData.cardType || "vehicle";

  const boldB64 = getFontBoldB64();
  const lightB64 = getFontLightB64();

  // Font size proportional to card dimensions (matches height * 0.08)
  const fontSize = Math.round(CARD_HEIGHT * 0.08); // ~86px at 1080
  const smallFontSize = Math.round(CARD_HEIGHT * 0.06); // ~65px for year
  const inset = Math.round(CARD_HEIGHT * 0.08); // ~86px padding

  // Build @font-face declarations
  let fontFaces = "";
  if (boldB64) {
    fontFaces += `@font-face { font-family: 'CardFont'; font-weight: 700; src: url('data:font/ttf;base64,${boldB64}') format('truetype'); }\n`;
  }
  if (lightB64) {
    fontFaces += `@font-face { font-family: 'CardFont'; font-weight: 300; src: url('data:font/ttf;base64,${lightB64}') format('truetype'); }\n`;
  }

  // Fallback font family
  const fontFamily = boldB64 ? "CardFont" : "sans-serif";

  // Shadow filter
  const shadowFilter = `
    <filter id="textShadow" x="-10%" y="-10%" width="130%" height="130%">
      <feDropShadow dx="0" dy="2" stdDeviation="3" flood-color="rgba(0,0,0,0.8)" />
    </filter>`;

  let textElements = "";

  if (cardType === "driver") {
    // Driver card: stacked layout (make, year, model)
    const line1Y = inset + fontSize;
    const line2Y = line1Y + smallFontSize + 2;
    const line3Y = line2Y + fontSize + 2;
    
    textElements = `
      <text x="${inset}" y="${line1Y}" font-family="${fontFamily}" font-weight="700" font-size="${fontSize}" fill="white" filter="url(#textShadow)">${escapeXML(make)}</text>`;
    
    if (year) {
      textElements += `
      <text x="${inset}" y="${line2Y}" font-family="${fontFamily}" font-weight="300" font-size="${smallFontSize}" fill="white" filter="url(#textShadow)">"${escapeXML(year)}"</text>`;
    }
    
    textElements += `
      <text x="${inset}" y="${line3Y}" font-family="${fontFamily}" font-weight="700" font-size="${fontSize}" fill="white" filter="url(#textShadow)">${escapeXML(model)}</text>`;

  } else if (cardType === "location") {
    // Location card: just the name, top-left
    const textY = inset + fontSize;
    textElements = `
      <text x="${inset}" y="${textY}" font-family="${fontFamily}" font-weight="700" font-size="${fontSize}" fill="white" filter="url(#textShadow)">${escapeXML(make)}</text>`;

  } else {
    // Vehicle card: make (light) + model (bold) on one line
    const textY = inset + fontSize;
    textElements = `
      <text x="${inset}" y="${textY}" filter="url(#textShadow)">
        <tspan font-family="${fontFamily}" font-weight="300" font-size="${fontSize}" fill="white">${escapeXML(make)}</tspan>
        <tspan dx="8" font-family="${fontFamily}" font-weight="700" font-size="${fontSize}" fill="white">${escapeXML(model)}</tspan>
      </text>`;
  }

  return `<svg width="${CARD_WIDTH}" height="${CARD_HEIGHT}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <style>${fontFaces}</style>
    ${shadowFilter}
  </defs>
  ${textElements}
</svg>`;
}

/**
 * Escape special XML characters in text.
 */
function escapeXML(str) {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

// ─── Core Flatten Logic ──────────────────────────────────────────────────────

/**
 * Flatten a single card: download photo, composite border + text, upload result.
 * 
 * @param {string} cardId - Firestore document ID
 * @param {object} cardData - Card document data
 * @returns {string} Download URL of the flat image
 */
async function flattenCard(cardId, cardData) {
  const uid = cardData.userId;
  if (!uid) throw new Error(`Card ${cardId} has no userId`);

  // 1. Determine the original photo path
  const photoURL = cardData.imageURL || cardData.photoURL;
  if (!photoURL) throw new Error(`Card ${cardId} has no photo URL`);

  // 2. Download the original photo from Storage
  const photoBuffer = await downloadFromURL(photoURL);

  // 3. Determine which border to use
  const borderFile = resolveBorder(cardData);
  const borderPath = path.join(__dirname, "borders", borderFile);
  
  if (!fs.existsSync(borderPath)) {
    console.warn(`Border file not found: ${borderFile}, using default`);
  }

  const actualBorderPath = fs.existsSync(borderPath) 
    ? borderPath 
    : path.join(__dirname, "borders", DEFAULT_BORDER);

  // 4. Build text overlay SVG
  const textSVG = buildTextOverlaySVG(cardData);
  const textBuffer = Buffer.from(textSVG);

  // 5. Composite: photo → border → text
  const flatBuffer = await compositeCard(photoBuffer, actualBorderPath, textBuffer);

  // 6. Upload with cache-busting timestamp
  const ts = Math.floor(Date.now() / 1000);
  const uploadPath = `cards/${uid}/${cardId}_flat_${ts}.jpg`;
  
  const bucket = storage.bucket();
  const file = bucket.file(uploadPath);
  
  await file.save(flatBuffer, {
    metadata: {
      contentType: "image/jpeg",
      cacheControl: "public, max-age=3600",
    },
  });

  // Make publicly accessible
  await file.makePublic();
  const downloadURL = `https://storage.googleapis.com/${bucket.name}/${uploadPath}`;

  // 7. Clean up old flat images (best-effort)
  await cleanupOldFlats(bucket, uid, cardId, ts);

  // 8. Update Firestore
  await db.collection("cards").doc(cardId).update({
    flatImageURL: downloadURL,
    flattenedAt: admin.firestore.FieldValue.serverTimestamp(),
    flattenedBy: "cloud-function",
  });

  // 9. Update activity feed if exists
  await updateActivityFeed(cardId, downloadURL, cardData);

  console.log(`✅ Flattened card ${cardId} (${borderFile}) → ${uploadPath}`);
  return downloadURL;
}

/**
 * Resolve the border PNG filename from card data.
 */
function resolveBorder(cardData) {
  // Priority: rarity > customFrame > default
  const rarity = cardData.specs?.rarity || cardData.rarity;
  if (rarity && BORDER_MAP[rarity.toLowerCase()]) {
    return BORDER_MAP[rarity.toLowerCase()];
  }

  const frame = cardData.customFrame;
  if (frame && BORDER_MAP[frame]) {
    return BORDER_MAP[frame];
  }

  return DEFAULT_BORDER;
}

/**
 * Download a file from a Firebase Storage URL.
 */
async function downloadFromURL(url) {
  const bucket = storage.bucket();
  
  // Parse the storage path from various URL formats
  let storagePath = null;
  
  if (url.includes("firebasestorage.googleapis.com")) {
    // Format: https://firebasestorage.googleapis.com/v0/b/BUCKET/o/PATH?...
    const match = url.match(/\/o\/(.+?)(\?|$)/);
    if (match) storagePath = decodeURIComponent(match[1]);
  } else if (url.includes("storage.googleapis.com")) {
    // Format: https://storage.googleapis.com/BUCKET/PATH
    const bucketName = bucket.name;
    const idx = url.indexOf(bucketName);
    if (idx >= 0) storagePath = url.substring(idx + bucketName.length + 1);
  }

  if (!storagePath) {
    // Try fetching as HTTP URL
    const response = await fetch(url);
    if (!response.ok) throw new Error(`Failed to download photo: ${response.status}`);
    return Buffer.from(await response.arrayBuffer());
  }

  const file = bucket.file(storagePath);
  const [buffer] = await file.download();
  return buffer;
}

/**
 * Composite the card photo with a border overlay and text using Sharp.
 */
async function compositeCard(photoBuffer, borderPath, textBuffer) {
  // Resize the photo to card dimensions (cover crop, centered)
  const resizedPhoto = await sharp(photoBuffer)
    .resize(CARD_WIDTH, CARD_HEIGHT, { fit: "cover", position: "centre" })
    .toBuffer();

  // Load border — SVGs need density option for crisp rendering at target size
  const isSVG = borderPath.toLowerCase().endsWith(".svg");
  let borderBuffer;
  if (isSVG) {
    // Render SVG at high density then resize to exact card dimensions
    borderBuffer = await sharp(borderPath, { density: 300 })
      .resize(CARD_WIDTH, CARD_HEIGHT, { fit: "fill" })
      .png()  // Convert to PNG buffer for compositing (preserves transparency)
      .toBuffer();
  } else {
    borderBuffer = await sharp(borderPath)
      .resize(CARD_WIDTH, CARD_HEIGHT, { fit: "fill" })
      .toBuffer();
  }

  // Build composite layers: photo → border → text
  const layers = [
    { input: borderBuffer, blend: "over" },
  ];

  if (textBuffer) {
    // Render SVG text to PNG at card dimensions for crisp overlay
    const textPng = await sharp(textBuffer)
      .resize(CARD_WIDTH, CARD_HEIGHT)
      .png()
      .toBuffer();
    layers.push({ input: textPng, blend: "over" });
  }

  // Composite all layers
  const result = await sharp(resizedPhoto)
    .composite(layers)
    .jpeg({ quality: 85 })
    .toBuffer();

  return result;
}

/**
 * Clean up old flat images for a card.
 */
async function cleanupOldFlats(bucket, uid, cardId, currentTs) {
  try {
    const prefix = `cards/${uid}/${cardId}_flat_`;
    const [files] = await bucket.getFiles({ prefix });
    
    for (const file of files) {
      if (!file.name.includes(`_flat_${currentTs}.jpg`)) {
        await file.delete().catch(() => {});
      }
    }
  } catch (err) {
    console.warn(`Cleanup warning for ${cardId}:`, err.message);
  }
}

/**
 * Update the activity feed entry for this card.
 */
async function updateActivityFeed(cardId, flatImageURL, cardData) {
  try {
    const uid = cardData.userId;
    if (!uid) return;

    // Query activity feed for this card
    const snapshot = await db.collection("activity")
      .where("cardId", "==", cardId)
      .where("userId", "==", uid)
      .limit(1)
      .get();

    if (!snapshot.empty) {
      const doc = snapshot.docs[0];
      const updateData = { flatImageURL };
      
      // Also update customFrame in activity if available
      const rarity = cardData.specs?.rarity || cardData.rarity;
      if (rarity) {
        const borderName = `Border_${rarity.charAt(0).toUpperCase() + rarity.slice(1).toLowerCase()}`;
        updateData.customFrame = borderName;
      }

      await doc.ref.update(updateData);
    }
  } catch (err) {
    console.warn(`Activity feed update warning for ${cardId}:`, err.message);
  }
}

// ─── Cloud Function Triggers ─────────────────────────────────────────────────

/**
 * Trigger: Auto-flatten when a card's rarity or customFrame changes.
 */
exports.onCardRarityChanged = onDocumentUpdated(
  {
    document: "cards/{cardId}",
    region: "us-central1",
    memory: "512MiB",
    timeoutSeconds: 120,
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const cardId = event.params.cardId;

    // Check if rarity or customFrame changed
    const rarityBefore = before.specs?.rarity || before.rarity;
    const rarityAfter = after.specs?.rarity || after.rarity;
    const frameBefore = before.customFrame;
    const frameAfter = after.customFrame;

    // Also trigger if flattenedBy was set to "request" (manual request)
    const requestFlatten = after.flattenRequested && !before.flattenRequested;

    if (rarityBefore === rarityAfter && frameBefore === frameAfter && !requestFlatten) {
      return; // No relevant changes
    }

    // Don't re-flatten if already done by cloud function recently
    if (after.flattenedBy === "cloud-function" && !requestFlatten) {
      return;
    }

    console.log(`🔄 Flattening card ${cardId}: rarity ${rarityBefore} → ${rarityAfter}`);
    
    try {
      await flattenCard(cardId, after);
    } catch (err) {
      console.error(`❌ Failed to flatten card ${cardId}:`, err);
    }
  }
);

/**
 * Callable: Flatten a specific card by ID.
 * Used by the app to request server-side flattening.
 */
exports.flattenSingleCard = onCall(
  {
    region: "us-central1",
    memory: "512MiB",
    timeoutSeconds: 120,
  },
  async (request) => {
    const { cardId } = request.data;
    if (!cardId) throw new HttpsError("invalid-argument", "cardId is required");

    // Verify the caller owns this card
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Must be authenticated");

    const cardDoc = await db.collection("cards").doc(cardId).get();
    if (!cardDoc.exists) throw new HttpsError("not-found", "Card not found");

    const cardData = cardDoc.data();
    if (cardData.userId !== uid) {
      throw new HttpsError("permission-denied", "Not your card");
    }

    try {
      const url = await flattenCard(cardId, cardData);
      return { success: true, flatImageURL: url };
    } catch (err) {
      console.error(`❌ flattenSingleCard failed for ${cardId}:`, err);
      throw new HttpsError("internal", err.message);
    }
  }
);

/**
 * Callable: Batch re-flatten all cards.
 * Admin-only — call after updating border designs.
 * Processes in batches to stay within Cloud Function timeout.
 */
exports.batchFlattenAll = onCall(
  {
    region: "us-central1",
    memory: "1GiB",
    timeoutSeconds: 540,
  },
  async (request) => {
    // Optional: restrict to admin UIDs
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Must be authenticated");

    const batchSize = request.data?.batchSize || 50;
    const startAfter = request.data?.startAfter || null;

    let query = db.collection("cards")
      .orderBy("__name__")
      .limit(batchSize);

    if (startAfter) {
      query = query.startAfter(startAfter);
    }

    const snapshot = await query.get();
    let success = 0;
    let failed = 0;
    let lastId = null;

    for (const doc of snapshot.docs) {
      lastId = doc.id;
      try {
        await flattenCard(doc.id, doc.data());
        success++;
      } catch (err) {
        console.error(`❌ Batch flatten failed for ${doc.id}:`, err.message);
        failed++;
      }
    }

    const hasMore = snapshot.docs.length === batchSize;

    return {
      processed: snapshot.docs.length,
      success,
      failed,
      lastId,
      hasMore,
    };
  }
);

/**
 * Scheduled: Optional periodic re-flatten for consistency.
 * Runs daily to catch any cards that missed flattening.
 */
// exports.scheduledFlatten = onSchedule(
//   {
//     schedule: "every day 03:00",
//     region: "us-central1",
//     memory: "1GiB",
//     timeoutSeconds: 540,
//   },
//   async (event) => {
//     // Find cards that haven't been flattened by cloud function
//     const snapshot = await db.collection("cards")
//       .where("flattenedBy", "!=", "cloud-function")
//       .limit(100)
//       .get();
//
//     let count = 0;
//     for (const doc of snapshot.docs) {
//       try {
//         await flattenCard(doc.id, doc.data());
//         count++;
//       } catch (err) {
//         console.error(`Scheduled flatten failed for ${doc.id}:`, err.message);
//       }
//     }
//     console.log(`Scheduled flatten complete: ${count} cards`);
//   }
// );
