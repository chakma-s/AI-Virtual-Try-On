let segSession = null;

async function segmentItem(imageDataUrl) {
  try {
    if (!segSession) {
      console.log('Loading U2-Net model...');
      segSession = await ort.InferenceSession.create(
        'https://huggingface.co/nickkuk/u2netp-onnx/resolve/main/u2netp.onnx',
        { executionProviders: ['webgl', 'wasm'] }
      );
    }

    const img = await new Promise((resolve, reject) => {
      const i = new Image(); i.crossOrigin = 'anonymous';
      i.onload = () => resolve(i); i.onerror = reject; i.src = imageDataUrl;
    });

    const SIZE = 320;
    const canvas = document.createElement('canvas');
    canvas.width = SIZE; canvas.height = SIZE;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(img, 0, 0, SIZE, SIZE);
    const imageData = ctx.getImageData(0, 0, SIZE, SIZE);

    const f32 = new Float32Array(3 * SIZE * SIZE);
    const mean = [0.485, 0.456, 0.406], std = [0.229, 0.224, 0.225];
    for (let c = 0; c < 3; c++)
      for (let i = 0; i < SIZE * SIZE; i++)
        f32[c * SIZE * SIZE + i] = (imageData.data[i * 4 + c] / 255.0 - mean[c]) / std[c];

    const results = await segSession.run({ [segSession.inputNames[0]]: new ort.Tensor('float32', f32, [1, 3, SIZE, SIZE]) });
    const outData = results[segSession.outputNames[0]].data;

    // 1. Sigmoid + Fixed Thresholding + Largest Component
    const mask = new Uint8Array(SIZE * SIZE);
    for (let i = 0; i < SIZE * SIZE; i++) {
      const prob = 1.0 / (1.0 + Math.exp(-outData[i]));
      mask[i] = prob > 0.5 ? 255 : 0;
    }

    // 2. Simple Connected Component Labeling to find the largest object
    const labels = new Int32Array(SIZE * SIZE).fill(-1);
    let nextLabel = 0;
    const componentSizes = {};

    for (let i = 0; i < SIZE * SIZE; i++) {
      if (mask[i] === 0 || labels[i] !== -1) continue;
      const label = nextLabel++;
      let size = 0;
      const stack = [i];
      while (stack.length > 0) {
        const curr = stack.pop();
        if (curr < 0 || curr >= SIZE * SIZE || labels[curr] !== -1 || mask[curr] === 0) continue;
        labels[curr] = label;
        size++;
        const x = curr % SIZE, y = Math.floor(curr / SIZE);
        if (x > 0) stack.push(curr - 1);
        if (x < SIZE - 1) stack.push(curr + 1);
        if (y > 0) stack.push(curr - SIZE);
        if (y < SIZE - 1) stack.push(curr + SIZE);
      }
      componentSizes[label] = size;
    }

    let largestLabel = -1, maxDim = 0;
    for (const label in componentSizes) {
      if (componentSizes[label] > maxDim) {
        maxDim = componentSizes[label];
        largestLabel = parseInt(label);
      }
    }

    // 3. Create Final Mask with soft edges (using original probs for the largest object)
    const finalAlpha = new Uint8Array(SIZE * SIZE);
    for (let i = 0; i < SIZE * SIZE; i++) {
      if (labels[i] === largestLabel) {
        const prob = 1.0 / (1.0 + Math.exp(-outData[i]));
        // Sharpen the probability transition
        const soft = Math.pow(prob, 2) * (3 - 2 * prob); // Smoothstep-like
        finalAlpha[i] = Math.round(soft * 255);
      } else {
        finalAlpha[i] = 0;
      }
    }

    // 4. Composite onto Original Image
    const outCanvas = document.createElement('canvas');
    outCanvas.width = img.naturalWidth; outCanvas.height = img.naturalHeight;
    const outCtx = outCanvas.getContext('2d');
    outCtx.drawImage(img, 0, 0);
    const out = outCtx.getImageData(0, 0, img.naturalWidth, img.naturalHeight);

    for (let y = 0; y < img.naturalHeight; y++) {
      for (let x = 0; x < img.naturalWidth; x++) {
        const mx = Math.floor(x * SIZE / img.naturalWidth);
        const my = Math.floor(y * SIZE / img.naturalHeight);
        out.data[(y * img.naturalWidth + x) * 4 + 3] = finalAlpha[my * SIZE + mx];
      }
    }
    outCtx.putImageData(out, 0, 0);
    return outCanvas.toDataURL('image/png');
  } catch (e) {
    console.error('Segmentation error:', e);
    return null;
  }
}

window.segmentItem = segmentItem;
