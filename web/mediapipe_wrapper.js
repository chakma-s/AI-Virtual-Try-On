let faceLandmarker;

async function initFaceLandmarker() {
  if (faceLandmarker) return;
  
  try {
    const vision = await import("https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.3/vision_bundle.mjs");
    
    const wasmFileset = await vision.FilesetResolver.forVisionTasks(
      "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.3/wasm"
    );
    
    faceLandmarker = await vision.FaceLandmarker.createFromOptions(wasmFileset, {
      baseOptions: {
        modelAssetPath: `https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task`,
        delegate: "GPU"
      },
      outputFaceBlendshapes: false,
      runningMode: "IMAGE",
      numFaces: 1
    });
    console.log("MediaPipe Face Landmarker initialized!");
  } catch (e) {
    console.error("Failed to load MediaPipe module:", e);
    throw e;
  }
}

async function detectFaces(imageUrl) {
  if (!faceLandmarker) await initFaceLandmarker();
  
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = "anonymous";
    img.onload = () => {
      try {
        const results = faceLandmarker.detect(img);
        if (results.faceLandmarks && results.faceLandmarks.length > 0) {
          // Add image width and height to result
          resolve({
            landmarks: results.faceLandmarks[0],
            width: img.width,
            height: img.height
          });
        } else {
          resolve(null);
        }
      } catch (e) {
        reject(e);
      }
    };
    img.onerror = reject;
    img.src = imageUrl;
  });
}

window.initFaceLandmarker = initFaceLandmarker;
window.detectFaces = detectFaces;
