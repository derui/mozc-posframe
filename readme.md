# Mozc with posframe #
`mozc-posframe` implements posframe-style for candidates displaying by [posframe](https://github.com/tumashu/posframe) .

The big inspiration get from [mozc-popup](https://github.com/d5884/mozc-popup) . This package is based on that package and big thanks to it.

## Set up ##
This package is not on ELPA/MELPA yet.

```emacs-lisp
;; download mozc-posframe.el and place it at your load-path.
(require 'mozc-posframe)
(setq mozc-candidate-style 'posframe)

;; Or if you enabled straight.el integration for use-package
(use-package mozc-posframe
  :straight (mozc-posframe :type git :host github :repo "derui/mozc-posframe")
  :require t)

;; Or if you use leaf.el
(leaf mozc-posframe
  :straight (mozc-posframe :type git :host github :repo "derui/mozc-posframe")
  :require t)
```

# LICENSE #
GPLv3

https://www.gnu.org/licenses/gpl-3.0.en.html
