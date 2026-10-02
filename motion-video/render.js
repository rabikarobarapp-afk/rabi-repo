// Renders scene.html frame-by-frame with Playwright and pipes frames into ffmpeg.
// Usage: node render.js [fps] [--preview t1,t2,...]
const { chromium } = require("playwright");
const { spawn } = require("child_process");
const path = require("path");

(async () => {
  const fps = Number(process.argv[2]) || 30;
  const previewArg = process.argv.indexOf("--preview");
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  await page.goto("file://" + path.join(__dirname, "scene.html"));
  const duration = await page.evaluate(() => window.DURATION);

  if (previewArg !== -1) {
    for (const t of process.argv[previewArg + 1].split(",").map(Number)) {
      await page.evaluate(t => window.render(t), t);
      await page.screenshot({ path: path.join(__dirname, "build", `preview_${t}.png`) });
    }
    await browser.close();
    return;
  }

  const ff = spawn("ffmpeg", ["-y", "-f", "image2pipe", "-framerate", String(fps), "-c:v", "mjpeg", "-i", "-",
    "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p",
    path.join(__dirname, "build", "video_silent.mp4")], { stdio: ["pipe", "ignore", "inherit"] });

  const frames = Math.round(duration * fps);
  for (let i = 0; i < frames; i++) {
    await page.evaluate(t => window.render(t), i / fps);
    const buf = await page.screenshot({ type: "jpeg", quality: 95 });
    if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once("drain", r));
    if (i % 90 === 0) process.stderr.write(`frame ${i}/${frames}\n`);
  }
  ff.stdin.end();
  await new Promise(r => ff.on("close", r));
  await browser.close();
})();
