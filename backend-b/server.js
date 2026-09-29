const express = require("express");

const app = express();

const HOST = "0.0.0.0";
const PORT = 3002;

app.get("/", (req, res) => {
  res.set("X-Backend", "B");

  res.json({
    backend: "B",
    status: "ok",
    message: "Backend B is running"
  });
});

app.get("/api/status", (req, res) => {
  res.set("X-Backend", "B");

  res.json({
    backend: "B",
    status: "ok"
  });
});

app.listen(PORT, HOST, () => {
  console.log(`Backend B listening on ${HOST}:${PORT}`);
});
