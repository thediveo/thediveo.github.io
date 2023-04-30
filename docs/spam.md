# Python

## 💤Linux Namespace Relations

Toy around with discovering Linux kernel namespaces using this
[linuxns_rel](https://thediveo.github.io/linuxns_rel) easy-to-use Python
library. It hides the crazy Linux namespace `ioctl()`s and thus simplifies some
aspects namespace discovery. On purpose, it does not replace the incredibly
useful [@zalando/python-nsenter](https://github.com/zalando/python-nsenter)
package, but instead complements it.

The `linuxns_rel` library actually sired the much more comprehensive
[lxkns](/gone?id=lxkns) Go module.

💤 In consequence, this Python library is now retired.
