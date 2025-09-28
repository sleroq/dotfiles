// ==UserScript==
// @name           hotkeys.uc.js
// @homepage       https://github.com/sleroq/dotfiles
// @description    Remaps
// @author         sleroq
// ==/UserScript==

const newTab = {
  id: "NewTab",
  modifiers: "ctrl",
  key: "S",
  command: "cmd_newNavigatorTab",
}

UC_API.Hotkeys.define(newTab).autoAttach({ suppressOriginal: true });

const newTabBlock = {
  id: "NewTabBlock",
  modifiers: "ctrl",
  key: "T",
  command: () => console.log("Blocked Ctrl+T. New tab remapped to Ctrl+S"),
}

UC_API.Hotkeys.define(newTabBlock).autoAttach({ suppressOriginal: true });


const copyCurrentURI = {
  id: "CopyCurrentURI",
  modifiers: "ctrl shift",
  key: "C",
  command: (window) =>
    navigator.clipboard.writeText(window.gBrowser.selectedBrowser.currentURI.spec),
}

UC_API.Hotkeys.define(copyCurrentURI).autoAttach({ suppressOriginal: true });
