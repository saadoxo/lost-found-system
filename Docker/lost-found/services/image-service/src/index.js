const express = require('express');
const helmet  = require('helmet');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { randomUUID } = require('crypto');

const app  = express();
const PORT = process.env.PORT || 3006;

app.use(helmet());
app.use(express.json({ limit: '10kb' }));

const s3 = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });
const BUCKET = process.env.S3_BUCKET;

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'image-service' }));
app.get('/ready',  (req, res) => res.json({ status: 'ready', service: 'image-service' }));

// Returns a pre-signed S3 URL — client uploads directly to S3
app.post('/images/upload-url', async (req, res) => {
  const { filename, contentType } = req.body;

  const allowed = ['image/jpeg', 'image/png', 'image/webp'];
  if (!allowed.includes(contentType)) {
    return res.status(400).json({ error: 'Only JPEG, PNG, and WebP are accepted' });
  }

  if (!BUCKET) {
    // Local dev fallback — return a fake URL so other services can be tested
    const imageKey = `items/${randomUUID()}-${filename}`;
    return res.json({
      uploadUrl: `http://localhost:3006/mock-upload/${imageKey}`,
      imageKey,
      expiresIn: 300
    });
  }

  try {
    const imageKey = `items/${randomUUID()}-${filename}`;
    const command  = new PutObjectCommand({
      Bucket:      BUCKET,
      Key:         imageKey,
      ContentType: contentType
    });

    const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 300 });

    res.json({ uploadUrl, imageKey, expiresIn: 300 });
  } catch (err) {
    console.error(JSON.stringify({ level: 'error', error: err.message }));
    res.status(500).json({ error: 'Failed to generate upload URL' });
  }
});

app.listen(PORT, () => {
  console.log(JSON.stringify({ level: 'info', message: `image-service listening on ${PORT}` }));
});