---
sidebar_position: 1
---

# Getting Started

`UniPlugin` is a Plugin wrapper that provides simple inter-plugin import/export semantics for public plugin apis.

What does this mean? It just means that if 2 plugins, say, PluginA and PluginB, they both use `UniPlugin`, then they are able to import apis of eachother using `UniPlugin:exportAs()` and `UniPlugin:withImports()`, setting their apis using `UniPlugin:setApi()`.

This makes interaction between different Plugins extremely trivial to do, and essentially "unifies" the plugins. Which is where the name "UniPlugin" comes from! "Unified Plugin".