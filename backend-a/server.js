const express = require("express");

const app = express();

const HOST = "0.0.0.0";
const PORT = 3001;

app.get("/", (req, res) => {
  res.set("X-Backend", "A");

  res.json({
    backend: "A",
    status: "ok",
    message: "Backend A is running"
  });
});

app.get("/api/status", (req, res) => {
  res.set("X-Backend", "A");

  res.json({
    backend: "A",
    status: "ok"
  });
});

app.listen(PORT, HOST, () => {
  console.log(`Backend A listening on ${HOST}:${PORT}`);
});
