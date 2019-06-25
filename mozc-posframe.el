;;; mozc-posframe.el --- Mozc with posframe

;; Copyright (C) 2019  Yuya Takahashi

;; Author: Yuya Takahashi <derutakayu@gmail.com>
;; Version: 0.1
;; Keywords: i18n, extentions
;; Package-Requires: ((posframe "0.4.3") (mozc "0"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This package implements posframe-style for candidates displaying by
;; `posframe' for' `mozc'.
;; This package is based on `mozc-popup.el' written by 'Daisuke Kobayashi <d5884jp@gmail.com>'

;;; Usage:

;; (require 'mozc-posframe)
;; (setq mozc-candidate-style 'posframe) ; select posframe style.

;;

;;; Code:

(require 'mozc)
(require 'posframe)

(unless (assoc 'posframe mozc-candidate-dispatch-table)
  (add-to-list 'mozc-candidate-dispatch-table
               '(posframe
                 (clean-up . mozc-cand-posframe-clean-up)
                 (clear . mozc-cand-posframe-clear)
                 (update . mozc-cand-posframe-update))))

(defvar mozc-posframe-buffer-name " *Mozc Posframe*"
  "Name of the buffer to render candidates")

(defface mozc-cand-overlay-description-face
  '((t (:inherit mozc-cand-overlay-odd-face)))
  "Face for description part of overlay candidate window."
  :group 'mozc-faces)

(defvar mozc-cand-posframe-position nil)
(make-variable-buffer-local 'mozc-cand-posframe-position)

(defconst mozc-cand-posframe-shortcut-spacer ". ")
(defconst mozc-cand-posframe-description-space 3)

(defun mozc-posframe--get-buffer ()
  (get-buffer-create mozc-posframe-buffer-name))

(defun mozc-posframe--apply-face (str face)
  (put-text-property 0 (length str) 'face face str)
  str)

(defun mozc-posframe--get-item-face (index focused-index)
  (if (and focused-index  (= focused-index index))
      'mozc-cand-overlay-focused-face
    (if (zerop (logand index 1))
        'mozc-cand-overlay-even-face
      'mozc-cand-overlay-odd-face)))

(defun mozc-posframe--render (candidates footer-label focused-index)
  "render candidates to posframe's buffer"
  ;; render candidates
  (with-current-buffer (mozc-posframe--get-buffer)
    (mapc
     (lambda (candidate)
       (let ((index (mozc-protobuf-get candidate 'index))
             (value (mozc-protobuf-get candidate 'value))
             (description (mozc-protobuf-get candidate 'annotation 'description))
             (shortcut (mozc-protobuf-get candidate 'annotation 'shortcut)))
         (insert
          (mozc-posframe--apply-face (if shortcut
                                         (concat shortcut
                                                 mozc-cand-posframe-shortcut-spacer
                                                 value
                                                 (if description
                                                     (concat
                                                      (cl-loop repeat mozc-cand-posframe-description-space
                                                               concat " ")
                                                      description)
                                                   ""))
                                       value)
                                     (mozc-posframe--get-item-face index focused-index)))
         (newline)))
     candidates)
    (when footer-label
      (insert (mozc-posframe--apply-face footer-label 'mozc-cand-overlay-footer-face)))))

(defun mozc-cand-posframe-draw (candidates)
  (let ((footer-label (mozc-protobuf-get candidates 'footer 'label))
        (focused-index (mozc-protobuf-get candidates 'focused-index))
        (sub-candidates (mozc-protobuf-get candidates 'subcandidates))
        (max-width 0))

    (when sub-candidates
      (setq footer-label
            (catch 'find-focused-value
              (dolist (candidate (mozc-protobuf-get candidates 'candidate))
                (let ((index (mozc-protobuf-get candidate 'index))
                      (value (mozc-protobuf-get candidate 'value))
                      (shortcut (mozc-protobuf-get candidate 'annotation 'shortcut)))
                  (when (eq index focused-index)
                    (throw 'find-focused-value
                           (concat (if shortcut (concat shortcut mozc-cand-posframe-shortcut-spacer value)
                                     value))))))))
      (setq focused-index (mozc-protobuf-get sub-candidates 'focused-index))
      (setq candidates sub-candidates))

    (mapc
     (lambda (candidate)
       (let ((index (mozc-protobuf-get candidate 'index))
             (value (mozc-protobuf-get candidate 'value))
             (description (mozc-protobuf-get candidate 'annotation 'description))
             (shortcut (mozc-protobuf-get candidate 'annotation 'shortcut)))
         (setq max-width (max (+ (string-width value)
                                 (if shortcut
                                     (+ (string-width
                                         mozc-cand-posframe-shortcut-spacer)
                                        (string-width shortcut)) 0)
                                 (if description
                                     (+ mozc-cand-posframe-description-space
                                        (string-width description)) 0))
                              max-width))))
     (mozc-protobuf-get candidates 'candidate))

    (let ((candidates-size (mozc-protobuf-get candidates 'size))
          (index-visible (mozc-protobuf-get candidates 'footer 'index-visible)))

      (if (and index-visible focused-index candidates-size)
          (let ((index-label (format "%d/%d" (1+ focused-index) candidates-size)))
            (setq footer-label
                  (format (concat "%" (number-to-string
                                       (max max-width (string-width index-label))) "s")
                          index-label)))
        (setq footer-label
              (concat
               footer-label
               (cl-loop repeat (max 0 (- max-width (string-width footer-label)))
                        concat " "))))

      (mozc-cand-posframe-clear)
      (mozc-posframe--render (mozc-protobuf-get candidates 'candidate) footer-label focused-index)
      (posframe-show (mozc-posframe--get-buffer)
                     :position mozc-cand-posframe-position))))

;;;###autoload
(defun mozc-cand-posframe-update (candidates)
  (unless mozc-cand-posframe-position
    (setq mozc-cand-posframe-position (posn-point mozc-preedit-posn-origin)))

  (condition-case nil
      (when (posframe-workable-p)
        (mozc-with-buffer-modified-p-unchanged
         (mozc-cand-posframe-draw candidates)))
    (error
     (mozc-cand-posframe-clear)
     ;; Fall back to the echo area version.
     (mozc-cand-echo-area-update candidates))))

;;;###autoload
(defun mozc-cand-posframe-clear ()
  (with-current-buffer (mozc-posframe--get-buffer)
    (erase-buffer)))

;;;###autoload
(defun mozc-cand-posframe-clean-up ()
  (with-current-buffer (mozc-posframe--get-buffer)
    (erase-buffer))
  (setq mozc-cand-posframe-position nil)
  (posframe-hide mozc-posframe-buffer-name))

(provide 'mozc-posframe)

;;; mozc-posframe.el ends here
