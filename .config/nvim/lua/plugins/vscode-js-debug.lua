return {
    "microsoft/vscode-js-debug",
    build = "npm ci --legacy-peer-deps && npx gulp vsDebugServerBundle && (rm out || true) && mv dist out"
}
