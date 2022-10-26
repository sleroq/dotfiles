;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
(setq user-full-name "Sleroq"
      user-mail-address "cantundo@pm.me")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-unicode-font' -- for unicode glyphs
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
(setq doom-font (font-spec :family "JetBrainsMono Nerd Font Mono" :size 16 :weight 'normal)
     doom-variable-pitch-font (font-spec :family "JetBrainsMono Nerd Font Mono" :size 17))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

(setq SAFE_PLACE (getenv "SAFE_PLACE"))

;; Treemacs
(map! :leader :desc "Treemacs toggle" :n "f t" #'+treemacs/toggle)
;; (map! :leader (:prefix ("f" . "file")) :desc "Treemacs toggle" :n "t" #'+treemacs/toggle)

;; Org-mode
(setq org-directory (concat SAFE_PLACE "/emacs-org/"))
(setq org-startup-with-inline-images t)

(setq org-agenda-files (list
    (concat SAFE_PLACE "/emacs-org/")))

;; Org-Roam
(setq org-roam-directory (concat SAFE_PLACE "/org-roam/"))
(add-to-list 'org-agenda-files (concat SAFE_PLACE "/org-roam/"))

(setq org-roam-capture-templates
    '(("d" "default" plain "%?" :target
        (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}\n")
        :unnarrowed t)
      ("p" "Person" plain "
* Info
Telegram: [[https://t.me/%^{Telegram username}][%\\1]]"
       :target
       (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "
#+PROPERTY: Birthday %^{Birthday|<0000-00-00>}
#+PROPERTY: CREATED %T
#+title: ${title}
#+filetags: :Person%^G")
       :unnarrowed t)))

(use-package! websocket
    :after org-roam)

(use-package! org-roam-ui
    :after org;; or :after org-roam
;;  if you don't care about startup time, use
;;  :hook (after-init . org-roam-ui-mode)
    :config
    (setq org-roam-ui-sync-theme t
          org-roam-ui-follow t
          org-roam-ui-update-on-save t
          org-roam-ui-open-on-start t))

;; Org-roam search with Deft (https://www.orgroam.com/manual.html#Full_002dtext-search-with-Deft)
(setq deft-use-filter-string-for-filename t)
(setq deft-directory org-roam-directory)
(setq deft-recursive t)

;; Spellcheck
(with-eval-after-load "ispell"
        (add-to-list
         'ispell-local-dictionary-alist
         '("en_US-large,ru_RU" "[[:alpha:]]" "[^[:alpha:]]" "['0-9]" t
           ("-d" "en_US-large,ru_RU")
           nil utf-8))

        (setq ispell-dictionary "en_US-large,ru_RU")
        (setq ispell-personal-dictionary (concat SAFE_PLACE "/files/ispell-dictionary.txt")))

;; Autosave
(setq auto-save-visited-mode t)
(setq auto-save-default t)

(defun save-all ()
        (interactive)
        (save-some-buffers t))

(add-function :after after-focus-change-function 'save-all)

;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
