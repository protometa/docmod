DocPad Async POC
================

This is a proof of concept of an asynchronous, file-based site builder for 
documents with DocPad metadata.

Hopefully this demonstrates how to avoid putting interdependant documents in 
memory for static template rendering, and allows for easier dynamic template
rendering.

Features

- Uses [gulp]() for streaming build, no cache, temp, or memory overload
- Queries documents on the filesystem treating them like a database
- Creates an index for faster queries