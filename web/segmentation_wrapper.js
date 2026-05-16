let segSession = null;

const SEG_MODEL_URL = 'https://huggingface.co/nickkuk/u2netp-onnx/resolve/main/u2netp.onnx';

async function initSegmentation() {
  if (segSession) return true;
  try {
    console.log('Loading U2-Net segmentation model...');
    segSession = await ort.InferenceSession.create(SEG_MODEL_URL, {
      executionProviders: ['webgl', 'wasm']
    });
    console.log('Segmentation model loaded!');
    return true;
  } catch (e) {
    console.error('Failed to load segmentation model:', e);
    return false;
  }
}

async function segmentItem(imageDataUrl) {
  const ok = await initSegmentation();
  if (!ok) return null;

  return new Promise((resolve) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = async () => {
      try {
        const SIZE = 320;
        const canvas = document.createElement('canvas');
        canvas.width = SIZE;
        canvas.height = SIZE;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, SIZE, SIZE);
        const imageData = ctx.getImageData(0, 0, SIZE, SIZE);

        // Preprocess: NCHW, ImageNet normalization
        const mean = [0.485, 0.456, 0.406];
        const std = [0.229, 0.224, 0.225];
        const float32 = new Float32Array(3 * SIZE * SIZE);
        for (let c = 0; c < 3; c++) {
          for (let i = 0; i < SIZE * SIZE; i++) {
            const val = imageData.data[i * 4 + c] / 255.0;
            float32[c * SIZE * SIZE + i] = (val - mean[c]) / std[c];
          }
        }

        const inputName = segSession.inputNames[0];
        const tensor = new ort.Tensor('float32', float32, [1, 3, SIZE, SIZE]);
        const feeds = {};
        feeds[inputName] = tensor;
        const results = await segSession.run(feeds);

        // First output is the main prediction
        const outName = segSession.outputNames[0];
        const outData = results[outName].data;

        // Sigmoid + min-max normalize to [0, 255]
        let minV = Infinity, maxV = -Infinity;
        const sig = new Float32Array(outData.length);
        for (let i = 0; i < outData.length; i++) {
          sig[i] = 1.0 / (1.0 + Math.exp(-outData[i]));
          if (sig[i] < minV) minV = sig[i];
          if (sig[i] > maxV) maxV = sig[i];
        }
        const range = maxV - minV || 1;
        const mask = new Array(SIZE * SIZE);
        for (let i = 0; i < SIZE * SIZE; i++) {
          mask[i] = Math.round(((sig[i] - minV) / range) * 255);
        }

        resolve({
          mask: mask,
          maskWidth: SIZE,
          maskHeight: SIZE,
          origWidth: img.naturalWidth,
          origHeight: img.naturalHeight
        });
      } catch (e) {
        console.error('Segmentation error:', e);
        resolve(null);
      }
    };
    img.onerror = () => resolve(null);
    img.src = imageDataUrl;
  });
}

window.initSegmentation = initSegmentation;
window.segmentItem = segmentItem;
