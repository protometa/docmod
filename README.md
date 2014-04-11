DocMod
======

Documents as Models
-------------------

*Express middleware that serves data files with optional templating, layouts, and dynamic content - Inspired by DocPad but atempts to be more scalable and modular*

At the most basic level, DocMod will serve YAML documents as a JSON service from clean urls. If the object contains a `body` field it will parse it as Markdown and serve that. If the object contains a `template` field, it will render it (currently only Jade) with the object locals and body and serve that. If the object contains a `layout` field it will inherit from another YAML document that itself may contain locals with its own `body`,`template`, and `layout` fields.

Other content (including dynamic content) can either be linked or loaded with the special `$link` or `$load` keys. These can accept relative paths or full url strings. The `$link` key will resolve relative paths to be used on the client (like an href). The `$load` key can accept a full `request` module options object. Loaded resources can be passed the original query and http headers to allow for fully dynamic content. For example, it can be used with a local `fscan` service to function as a file-based content management system. Loading or linking can be interchanged to do things on the server or the client respectively.


