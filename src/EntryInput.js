// Shared parsing and normalization for quick capture and log editing.

function splitImagePaths(text) {
    var raw = (text || "").split(/[\n,]/);
    var paths = [];
    for (var i = 0; i < raw.length; i++) {
        var path = raw[i].trim();
        if (path) paths.push(path);
    }
    return paths;
}

function normalizeImageText(text) {
    return splitImagePaths(text).join("\n");
}

function parseLogInput(raw) {
    var text = (raw || "").trim();
    var separator = text.indexOf("|");
    if (separator >= 0) {
        var metadata = parseLogTokens(text.slice(separator + 1), false);
        metadata.content = text.slice(0, separator).trim();
        return metadata;
    }
    return parseLogTokens(text, true);
}

function parseLogTokens(raw, collectContent) {
    var tokens = (raw || "").trim().split(/\s+/);
    var result = { content: "", mood: "", tags: [], project: "" };
    var contentParts = [];
    for (var i = 0; i < tokens.length; i++) {
        var token = tokens[i];
        if (!token) continue;
        if (token.indexOf("mood:") === 0 || token.indexOf("mood：") === 0) {
            var mood = token.slice(5).trim();
            if (!mood && i + 1 < tokens.length) mood = tokens[++i];
            result.mood = mood;
        } else if (token.indexOf("project:") === 0 || token.indexOf("project：") === 0) {
            var project = token.slice(8).trim();
            if (!project && i + 1 < tokens.length) project = tokens[++i];
            result.project = project;
        } else if (token[0] === "#") {
            var tag = token.slice(1).replace(/[，,。.!?！？；;：:]+$/, "").trim();
            if (tag) result.tags.push(tag);
        } else if (collectContent) {
            contentParts.push(token);
        }
    }
    if (collectContent) result.content = contentParts.join(" ");
    return result;
}

// Returns null when no images were supplied, or an error object for invalid input.
function buildLogPayload(inputText, imageText) {
    var images = splitImagePaths(imageText);
    if (images.length === 0) return null;

    var parsed = parseLogInput(inputText);
    var content = (parsed.content || "").trim();
    if (!content) return { error: "内容不能为空" };

    return {
        content: content,
        mood: parsed.mood,
        tags: parsed.tags,
        project: parsed.project,
        images: images
    };
}

function editLogImageArgs(originalText, currentText) {
    if (normalizeImageText(originalText) === normalizeImageText(currentText)) return [];
    var paths = splitImagePaths(currentText);
    if (paths.length === 0) return ["--clear-images"];
    var args = [];
    for (var i = 0; i < paths.length; i++) args.push("--image", paths[i]);
    return args;
}

if (typeof module !== "undefined") {
    module.exports = {
        splitImagePaths: splitImagePaths,
        normalizeImageText: normalizeImageText,
        parseLogInput: parseLogInput,
        parseLogTokens: parseLogTokens,
        buildLogPayload: buildLogPayload,
        editLogImageArgs: editLogImageArgs
    };
}
