export function parseMarkdown(markdown) {
  if (!markdown) {
    return "";
  }

  let html = markdown.replace(/\r\n/g, "\n");

  // Escape HTML
  html = html
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");

  const lines = html.split("\n");
  let result = [];

  let inUl = false;
  let inOl = false;

  for (let line of lines) {
    const trimmed = line.trim();

    if (!trimmed) {
      if (inUl) {
        result.push("</ul>");
        inUl = false;
      }
      if (inOl) {
        result.push("</ol>");
        inOl = false;
      }
      continue;
    }

    // Headings
    if (trimmed.startsWith("### ")) {
      closeLists();
      result.push("<h3>" + inline(trimmed.substring(4)) + "</h3>");
      continue;
    }

    if (trimmed.startsWith("## ")) {
      closeLists();
      result.push("<h2>" + inline(trimmed.substring(3)) + "</h2>");
      continue;
    }

    if (trimmed.startsWith("# ")) {
      closeLists();
      result.push("<h1>" + inline(trimmed.substring(2)) + "</h1>");
      continue;
    }

    // Bullet List
    if (/^[-*]\s+/.test(trimmed)) {
      if (!inUl) {
        closeLists();
        result.push("<ul>");
        inUl = true;
      }

      result.push("<li>" + inline(trimmed.replace(/^[-*]\s+/, "")) + "</li>");
      continue;
    }

    // Numbered List
    if (/^\d+\.\s+/.test(trimmed)) {
      if (!inOl) {
        closeLists();
        result.push("<ol>");
        inOl = true;
      }

      result.push("<li>" + inline(trimmed.replace(/^\d+\.\s+/, "")) + "</li>");
      continue;
    }

    closeLists();
    result.push("<p>" + inline(trimmed) + "</p>");
  }

  closeLists();

  return result.join("");

  function closeLists() {
    if (inUl) {
      result.push("</ul>");
      inUl = false;
    }

    if (inOl) {
      result.push("</ol>");
      inOl = false;
    }
  }

  function inline(text) {
    return text
      .replace(/\*\*(.*?)\*\*/g, "<strong>$1</strong>")
      .replace(/\*(.*?)\*/g, "<em>$1</em>")
      .replace(/`([^`]+)`/g, "<code>$1</code>")
      .replace(/\n/g, "<br/>");
  }
}
