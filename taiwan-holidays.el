;;; taiwan-holidays.el --- Localized calendar for Emacsers in Taiwan.

;; Copyright (C) 2006, 2007, 2008, 2009, 2010 William Xu
;; Copyright (C) 2015 Kuan Yen
;; Author: kuanyui <azazabc123@gmail.com>
;; Version: 2.4
;; Url: http://github.com/emacs-tw/taiwan-holidays.el

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
;; MA 02110-1301, USA.

;;; Commentary:

;; This extension mainly adds the following extra features:
;;   - Taiwan localizations
;;   - Display holiday, lunar, horoscope, zodiac, solar term info on mode line
;;   - Define holidays using `holiday-lunar', `holiday-solar-term'
;;   - Highlight holidays based on different priorities
;;   - Add `taiwan-holidays-taiwan-holidays', `taiwan-holidays-japanese-holidays'.
;;
;; To use, add something like the following to your .emacs:
;;     (require 'taiwan-holidays)
;;     (setq mark-holidays-in-calendar t)
;;     (setq taiwan-holidays-important-holidays taiwan-holidays-taiwan-holidays)
;;     (setq calendar-holidays taiwan-holidays-important-holidays)
;;

;;; History

;; `taiwan-holidays.el' is forked from `cal-china-x.el', written by
;; William Xu <william.xwl@gmail.com>

;; `cal-china-x.el' is an early derived work from `chinese-calendar.el' written by
;; Charles Wang <charleswang@peoplemail.com.cn>.

;;; TODO:

;; - Display week day(the first line of each month) in chinese properly

;;; Code:

(require 'calendar)
(require 'holidays)
(require 'cal-china)
(eval-when-compile (require 'cl))

;;; Variables

;; Bound in calendar-generate.
(defvar displayed-month)
(defvar displayed-year)

(defconst taiwan-holidays-celestial-stem
  ["甲" "乙" "丙" "丁" "戊" "已" "庚" "辛" "壬" "癸"])

(defconst taiwan-holidays-terrestrial-branch
  ["子" "丑" "寅" "卯" "辰" "巳" "午" "未" "申" "酉" "戌" "亥"])

(defconst taiwan-holidays-days
  ["日" "一" "二" "三" "四" "五" "六"])

(defconst taiwan-holidays-month-name
  ["正月" "二月" "三月" "四月" "五月" "六月" "七月" "八月" "九月" "十月"
   "十一月" "腊月"])

(defconst taiwan-holidays-day-name
  ["初一" "初二" "初三" "初四" "初五" "初六" "初七" "初八" "初九" "初十"
   "十一" "十二" "十三" "十四" "十五" "十六" "十七" "十八" "十九"  "廿"
   "廿一" "廿二" "廿三" "廿四" "廿五" "廿六" "廿七" "廿八" "廿九" "三十"
   "卅一" "卅二" "卅三" "卅四" "卅五" "卅六" "卅七" "卅八" "卅九" "卅十"])

(defvar chinese-date-diary-pattern
  `((year "年" month "月" day "日" " 星期[" ,(mapconcat 'identity taiwan-holidays-days "") "]")
    ,@(if (> emacs-major-version 22)
          diary-iso-date-forms
        '((month "[-/]" day "[^-/0-9]")
          (year "[-/]" month "[-/]" day "[^0-9]")
          (monthname "-" day "[^-0-9]")
          (year "-" monthname "-" day "[^0-9]")
          (dayname "\\W")))))

(defconst taiwan-holidays-horoscope-name
  '(((3 21) (4 19) "白羊")
    ((4 20) (5 20) "金牛")
    ((5 21) (6 21) "雙子")
    ((6 22) (7 22) "巨蟹")
    ((7 23) (8 22) "獅子")
    ((8 23) (9 22) "處女")
    ((9 23) (10 23) "天秤")
    ((10 24) (11 22) "天蝎")
    ((11 23) (12 21) "射手")
    ((12 22) (1 19) "摩羯")
    ((1 20) (2 18) "水瓶")
    ((2 19) (3 20) "雙魚")))

(defconst taiwan-holidays-zodiac-name
  ["鼠" "牛" "虎" "兔" "龍" "蛇" "馬" "羊" "猴" "鷄" "狗" "豬"]
  "The zodiac(生肖) when you were born.")

;; for ref, http://www.geocities.com/calshing/chinesecalendar.htm
(defconst taiwan-holidays-solar-term-name
  ["小寒" "大寒" "立春" "雨水" "驚蟄" "春分"
   "清明" "穀雨" "立夏" "小滿" "芒種" "夏至"
   "小暑" "大暑" "立秋" "處暑" "白露" "秋分"
   "寒露" "霜降" "立冬" "小雪" "大雪" "冬至"]
  "24 solar terms(節氣, in chinese).
\"小寒\" is the first solar term in a new year. e.g., 2007-01-06.
There is a short poem for remembering,

春雨驚春清穀天，夏滿芒夏暑相連，
秋處露秋寒霜降，冬雪雪冬小大寒。")

(defconst taiwan-holidays-japanese-holidays
  '((holiday-fixed 1 1 "元旦")
    (holiday-fixed 1 2 "公務員法定休息日")
    (holiday-fixed 1 3 "公務員法定休息日")
    (holiday-fixed 1 4 "公務員法定休息日")
    (holiday-float 1 1 1 "成人の日")
    (holiday-fixed 2 11 "建國記念の日")
    (holiday-solar-term "春分" "春分の日")
    (holiday-fixed 4 29 "みどりの日")
    (holiday-fixed 5 3 "憲法記念日")
    (holiday-fixed 5 4 "國民の休日")
    (holiday-fixed 5 5 "こどもの日")
    (holiday-fixed 7 20 "海の日")
    (holiday-fixed 9 15 "敬老の日")
    (holiday-solar-term "秋分" "秋分の日")
    (holiday-float 10 1 0 "體育の日")
    (holiday-fixed 11 3 "文化の日")
    (holiday-fixed 11 23 "勤勞感謝の日")
    (holiday-fixed 12 23 "天皇誕生日")
    (holiday-fixed 12 28 "公務員法定休息日")
    (holiday-fixed 12 29 "公務員法定休息日")
    (holiday-fixed 12 30 "公務員法定休息日")
    (holiday-fixed 12 31 "公務員法定休息日"))
  "Pre-defined japanese public holidays.
You can add this to your `calendar-holidays'.")

(defvar taiwan-holidays-taiwan-holidays
  '((holiday-fixed 1 1 "元旦")
    (holiday-lunar 12 30 "除夕" 0)
    (holiday-lunar 1 1 "春節" 0)
    (holiday-lunar 1 2 "大年初二" 0)
    (holiday-fixed 2 28 "228 和平紀念日")
    (holiday-fixed 4 4 "兒童節")
    (holiday-solar-term "清明" "清明節")
    (holiday-fixed 5 1 "勞動節")
    (holiday-lunar 5 5 "端午節" 0)
    (holiday-lunar 8 15 "中秋節" 0)
    (holiday-fixed 10 10 "國慶日"))
  "Pre-defined taiwan public holidays.
You can add this to your `calendar-holidays'.")


;;; Interfaces

(defgroup taiwan-holidays nil
  "Chinese calendar extentions and more."
  :group 'calendar)

(defcustom taiwan-holidays-important-holidays '()
  "Highlighted by `taiwan-holidays-important-holiday-face'."
  :type 'symbol
  :group 'taiwan-holidays)

(defcustom taiwan-holidays-general-holidays '()
  "Highlighted by `taiwan-holidays-general-holiday-face'."
  :type 'symbol
  :group 'taiwan-holidays)

(defface taiwan-holidays-important-holiday-face
  '((((class color) (background light))
     (:foreground "#ffffff" :background "#a40000"))
    (((class color) (background dark))
     (:foreground "#ffffff" :background "#a40000"))
    (t
     :inverse-video t))
  "Face for indicating `taiwan-holidays-important-holidays'."
  :group 'taiwan-holidays)

(defface taiwan-holidays-general-holiday-face
  '((((class color) (background light))
     (:foreground "#008700" :background "#d7ff87"))
    (((class color) (background dark))
     (:foreground "#a1db00" :background "#5a5a5a"))
    (t
     :inverse-video t))
  "Face for indicating `taiwan-holidays-general-holidays'."
  :group 'taiwan-holidays)

(defcustom taiwan-holidays-custom-week-start-date '()
  "The month and day of first Monday in your custom week diary.

e.g., '(9 20) means from every year, Sep 20th will be defined as
the first week.  This could be useful in some circumstances, such
as schools, where people may use some specific school diary."
  :type 'symbol
  :group 'taiwan-holidays)

;;;###autoload
(defun taiwan-holidays-birthday-from-chinese (lunar-month lunar-day)
  "Return birthday date this year in Gregorian form.

LUNAR-MONTH and LUNAR-DAY are date number used in chinese lunar
calendar."
  (interactive "nlunar month: \nnlunar day: ")
  (let* ((birthday-chinese (list lunar-month lunar-day))
	 (current-chinese-date (calendar-chinese-from-absolute
				(calendar-absolute-from-gregorian
				 (calendar-current-date))))
	 (cycle (car current-chinese-date))
	 (year (cadr current-chinese-date))
	 (birthday-chinese-full `(,cycle ,year ,@birthday-chinese))
	 (birthday-gregorian-full (calendar-gregorian-from-absolute
				   (calendar-chinese-to-absolute
				    birthday-chinese-full))))
    (message "Your next birthday in gregorian is on %s"
	     (calendar-date-string birthday-gregorian-full))))

;;;###autoload
(defun holiday-lunar (lunar-month lunar-day string &optional num)
  "Like `holiday-fixed', but with LUNAR-MONTH and LUNAR-DAY.

When there are multiple days(like Run Yue or 闰月, e.g.,
2006-08-30, which is 07-07 in lunar calendar, the chinese
valentine's day), we use NUM to define which day(s) as
holidays. The rules are:

NUM = 0, only the earlier day.
NUM = 1, only the later day.
NUM with other values(default), all days(maybe one or two).

emacs23 introduces a similar `holiday-chinese', a quick test
shows that it does not recognize Run Yue at all."
  (unless (integerp num)
    (setq num 2))
  (let* ((cn-years (calendar-chinese-year displayed-year))
         (ret (holiday-lunar-1
               (assoc lunar-month cn-years) lunar-day string)))
    (when (and (> (length cn-years) 12) (not (zerop num)))
      (let ((run-yue '())
            (years cn-years)
            (i '()))
        (while years
          (setq i (car years)
                years (cdr years))
          (unless (integerp (car i))
            (setq run-yue i)
            (setq years nil)))
        (when (= lunar-month (floor (car run-yue)))
          (setq ret (append ret (holiday-lunar-1
                                 run-yue lunar-day string))))))
    (cond ((= num 0)
           (when (car ret) (list (car ret))))
          ((= num 1)
           (if (cadr ret) (list (cadr ret)) ret))
          (t
           ret))))

(defun holiday-lunar-1 (run-yue lunar-day string)
  (let* ((date (calendar-gregorian-from-absolute
                (+ (cadr run-yue) (1- lunar-day))))
         (holiday (holiday-fixed (car date) (cadr date) string)))
    ;; Same year?
    (when (and holiday (= (nth 2 (caar holiday)) (nth 2 date)))
      holiday)))

;;;###autoload
(defun holiday-solar-term (solar-term str)
  "A holiday(STR) on SOLAR-TERM day.
See `taiwan-holidays-solar-term-name' for a list of solar term names ."
  (taiwan-holidays-sync-solar-term displayed-year)
  (let ((terms taiwan-holidays-solar-term-alist)
        i date)
    (while terms
      (setq i (car terms)
            terms (cdr terms))
      (when (string= (cdr i) solar-term)
        (let ((m (caar i))
              (y (caddar i)))
          ;; '(11 12 1), '(12 1 2)
          (when (or (and (taiwan-holidays-cross-year-view-p)
                         (or (and (= displayed-month 12)
                                  (= m 1)
                                  (= y (1+ displayed-year)))
                             (and (= displayed-month 1)
                                  (= m 12)
                                  (= y (1- displayed-year)))))
                    (= y displayed-year))
            (setq terms '()
                  date (car i))))))
    (holiday-fixed (car date) (cadr date) str)))

(defun taiwan-holidays-calendar-display-form (date)
  (if (equal date '(0 0 0))
      ""
    (format "%04d年%02d月%02d日 %s"
            (calendar-extract-year date)
            (calendar-extract-month date)
            (calendar-extract-day date)
            (taiwan-holidays-day-name date))))

(defun taiwan-holidays-chinese-date-string (date)
  (let* ((cn-date (calendar-chinese-from-absolute
                   (calendar-absolute-from-gregorian date)))
         (cn-year  (cadr   cn-date))
         (cn-month (caddr  cn-date))
         (cn-day   (cadddr cn-date)))
    (format "%s%s年%s%s%s(%s)%s"
            (calendar-chinese-sexagesimal-name cn-year)
            (aref taiwan-holidays-zodiac-name (% (1- cn-year) 12))
            (aref taiwan-holidays-month-name (1-  (floor cn-month)))
            (if (integerp cn-month) "" "(閏月)")
            (aref taiwan-holidays-day-name (1- cn-day))
            (taiwan-holidays-get-horoscope (car date) (cadr date))
            (taiwan-holidays-get-solar-term date))))

(defun taiwan-holidays-setup ()
  (setq calendar-date-display-form
	'((taiwan-holidays-calendar-display-form
           (mapcar (lambda (el) (string-to-number el))
                   (list month day year)))))

  (setq diary-date-forms chinese-date-diary-pattern)

  ;; chinese month and year
  (if (< emacs-major-version 27)
      (setq calendar-font-lock-keywords
            (append calendar-font-lock-keywords
                    '(("[0-9]+年\\ *[0-9]+月" . font-lock-function-name-face)))))

  (setq calendar-chinese-celestial-stem taiwan-holidays-celestial-stem
	calendar-chinese-terrestrial-branch taiwan-holidays-terrestrial-branch)

  (setq calendar-mode-line-format
        (list
         (calendar-mode-line-entry 'calendar-scroll-right "previous month" "<")
         "Calendar"

         '(taiwan-holidays-get-holiday date)

         '(concat (calendar-date-string date t)
                  (format " 第%d周"
                          (funcall (if taiwan-holidays-custom-week-start-date
                                       'taiwan-holidays-custom-week-of-date
                                     'taiwan-holidays-week-of-date)
                                   date)))

         '(taiwan-holidays-chinese-date-string date)

         ;; (concat
         ;;  (calendar-mode-line-entry 'calendar-goto-info-node "read Info on Calendar"
         ;;                            nil "info")
         ;;  " / "
         ;;  (calendar-mode-line-entry 'calendar-other-month "choose another month"
         ;;                            nil "other")
         ;;  " / "
         ;;  (calendar-mode-line-entry 'calendar-goto-today "go to today's date"
         ;;                            nil "today"))

         (calendar-mode-line-entry 'calendar-scroll-left "next month" ">")))

  (add-hook 'calendar-move-hook 'calendar-update-mode-line)
  (add-hook 'calendar-initial-window-hook 'calendar-update-mode-line)

  (defadvice mouse-set-point (after calendar-update-mode-line activate)
    (when (eq major-mode 'calendar-mode)
      (calendar-update-mode-line))))


;;; Implementations

(defun taiwan-holidays-day-name (date)
  "Chinese day name in a week, like `星期一'."
  (concat "星期" (aref taiwan-holidays-days (calendar-day-of-week date))))

(defun taiwan-holidays-day-short-name (num)
  "Short chinese day name in a week, like `一'. NUM is from 0..6
in a week."
  (aref taiwan-holidays-days num))

(defun taiwan-holidays-get-horoscope (month day)
  "Return horoscope(星座) on MONTH(1-12) DAY(1-31)."
  (catch 'return
    (mapc
     (lambda (el)
       (let ((start (car el))
             (end (cadr el)))
         (when (or (and (= month (car start)) (>= day (cadr start)))
                   (and (= month (car end)) (<= day (cadr end))))
           (throw 'return (caddr el)))))
     taiwan-holidays-horoscope-name)))

(defun holiday-chinese-new-year ()
  "Date of Chinese New Year."
  (let ((m displayed-month)
        (y displayed-year))
    (calendar-increment-month m y 1)
    (if (< m 5)
        (let ((chinese-new-year
               (calendar-gregorian-from-absolute
                (cadr (assoc 1 (calendar-chinese-year y))))))
          (if (calendar-date-is-visible-p chinese-new-year)
	      `((,chinese-new-year
                 ,(format "%s年春節"
                          (calendar-chinese-sexagesimal-name
                           (+ y 57))))))))))

(defun taiwan-holidays-get-solar-term (date)
  (let ((year (calendar-extract-year date)))
    (taiwan-holidays-sync-solar-term year)
    (or (cdr (assoc date taiwan-holidays-solar-term-alist)) "")))

(defun taiwan-holidays-solar-term-alist-new (year)
  "Return a solar-term alist for YEAR."
  (loop for i from 0 upto 23

        for date = (taiwan-holidays-next-solar-term `(1 1 ,year))
        then (setq date (taiwan-holidays-next-solar-term date))

        with solar-term-alist = '()

        collect (cons date (aref taiwan-holidays-solar-term-name i))
        into solar-term-alist

        finally return solar-term-alist))

(defun taiwan-holidays-gregorian-from-astro (a)
  (calendar-gregorian-from-absolute
   (floor (calendar-astro-to-absolute a))))

(defun taiwan-holidays-astro-from-gregorian (g)
  (calendar-astro-from-absolute
   (calendar-absolute-from-gregorian g)))

(defun taiwan-holidays-next-solar-term (date)
  "Return next solar term's data after DATE.
Each solar term is separated by 15 longtitude degrees or so, plus an
extra day appended."
  (taiwan-holidays-gregorian-from-astro
   (solar-date-next-longitude
    (calendar-astro-from-absolute
     (1+ (calendar-absolute-from-gregorian date))) 15)))

(defun taiwan-holidays-get-holiday (date)
  (when (and (boundp 'displayed-month)
             (boundp 'displayed-year))
    (let ((holidays (calendar-holiday-list))
          (str ""))
      (dolist (i holidays)
        (when (equal (car i) date)
          (setq str (concat str " " (cadr i)))))
      str)))

;; cached solar terms for two neighbour years at most.
(defvar taiwan-holidays-solar-term-alist nil) ; e.g., '(((1 20 2008) "春分") ...)
(defvar taiwan-holidays-solar-term-years nil)

(defun taiwan-holidays-sync-solar-term (year)
  "Sync `taiwan-holidays-solar-term-alist' and `taiwan-holidays-solar-term-years' to YEAR."
  (cond ((or (not taiwan-holidays-solar-term-years)
             ;; TODO: Seems calendar-update-mode-line is called too early in
             ;; calendar-mode.
             (not (boundp 'displayed-year))
             (not (boundp 'displayed-month)))
         (setq taiwan-holidays-solar-term-alist
               (taiwan-holidays-solar-term-alist-new year))
         (setq taiwan-holidays-solar-term-years (list year)))
        ((not (memq year taiwan-holidays-solar-term-years))
         (setq taiwan-holidays-solar-term-alist
               (append
                (cl-remove-if-not (lambda (i) (eq (caddar i) displayed-year))
                               taiwan-holidays-solar-term-alist)
                (taiwan-holidays-solar-term-alist-new year)))
         (setq taiwan-holidays-solar-term-years
               (cons year (cl-remove-if-not (lambda (i) (eq i displayed-year))
                                         taiwan-holidays-solar-term-years))))))

;; When months are: '(11 12 1), '(12 1 2)
(defun taiwan-holidays-cross-year-view-p ()
  (or (= displayed-month 12) (= displayed-month 1)))

;; ,----
;; | week
;; `----

(defun taiwan-holidays-week-of-date (date)
  "Get week number from DATE."
  (car (calendar-iso-from-absolute (calendar-absolute-from-gregorian date))))

(defun taiwan-holidays-custom-week-of-date (date)
  "Similar to `taiwan-holidays-week-of-date' but starting from `taiwan-holidays-custom-week-start-date'."
  (let ((y (calendar-extract-year date)))
    (when (or (< (calendar-extract-month date)
                 (car taiwan-holidays-custom-week-start-date))
              (< (calendar-extract-day date)
                 (cadr taiwan-holidays-custom-week-start-date)))
      (setq y (1- y)))
    (ceiling (/ (taiwan-holidays-days-between
                 date (append taiwan-holidays-custom-week-start-date (list y)))
                7.0))))

(defun taiwan-holidays-days-between (date1 date2)
  (apply '- (mapcar 'calendar-absolute-from-gregorian (list date1 date2))))


;;; Modifications to Standard Functions

;; These functions(from calendar.el, cal-china.el) have been modified
;; for localization.

(defun calendar-chinese-sexagesimal-name (n)
  "The N-th name of the Chinese sexagesimal cycle.
N congruent to 1 gives the first name, N congruent to 2 gives the second name,
..., N congruent to 60 gives the sixtieth name."
  ;; Change "%s-%s" to "%s%s", since adding the extra `-' between two Chinese
  ;; characters looks stupid.
  (format "%s%s"
          (aref calendar-chinese-celestial-stem (% (1- n) 10))
          (aref calendar-chinese-terrestrial-branch (% (1- n) 12))))

(defadvice calendar-mark-holidays (around mark-different-holidays activate)
  "Mark holidays with different priorities."
  (let ((calendar-holiday-marker 'taiwan-holidays-important-holiday-face)
        (calendar-holidays taiwan-holidays-important-holidays))
    ad-do-it)
  (let ((calendar-holiday-marker 'taiwan-holidays-general-holiday-face)
        (calendar-holidays taiwan-holidays-general-holidays))
    ad-do-it)
  (let ((calendar-holidays
         (cl-remove-if (lambda (i)
                      (or (member i taiwan-holidays-important-holidays)
                          (member i taiwan-holidays-general-holidays)))
                    calendar-holidays)))
    ad-do-it))

(defun calendar-generate-month (month year indent)
  "Produce a calendar for MONTH, YEAR on the Gregorian calendar.
The calendar is inserted at the top of the buffer in which point is currently
located, but indented INDENT spaces.  The indentation is done from the first
character on the line and does not disturb the first INDENT characters on the
line."
  (let ((blank-days               ; at start of month
         (mod
          (- (calendar-day-of-week (list month 1 year))
             calendar-week-start-day)
          7))
        (last (calendar-last-day-of-month month year))
        (trunc (min calendar-intermonth-spacing
                    (1- calendar-left-margin)))
        (day 1)
        string)
    (goto-char (point-min))
    (calendar-move-to-column indent)
    (insert
     (calendar-string-spread
      (list (format "%d年%2d月" year month))
      ?\s calendar-month-digit-width))
    (calendar-ensure-newline)
    (calendar-insert-at-column indent calendar-intermonth-header trunc)
    ;; Use the first two characters of each day to head the columns.
    (dotimes (i 7)
      (insert
       (progn
         (setq string
               (calendar-day-name (mod (+ calendar-week-start-day i) 7) nil t))
         ;; (taiwan-holidays-day-short-name (mod (+ calendar-week-start-day i) 7)))
         (if enable-multibyte-characters
             (truncate-string-to-width string calendar-day-header-width)
           (substring string 0 calendar-day-header-width)))
       (make-string (- calendar-column-width calendar-day-header-width) ?\s)))
    (calendar-ensure-newline)
    (calendar-insert-at-column indent calendar-intermonth-text trunc)
    ;; Add blank days before the first of the month.
    (insert (make-string (* blank-days calendar-column-width) ?\s))
    ;; Put in the days of the month.
    (dotimes (i last)
      (setq day (1+ i))
      ;; TODO should numbers be left-justified, centered...?
      (insert (format (format "%%%dd%%s" calendar-day-digit-width) day
                      (make-string
                       (- calendar-column-width calendar-day-digit-width) ?\s)))
      ;; 'date property prevents intermonth text confusing re-searches.
      ;; (Tried intangible, it did not really work.)
      (set-text-properties
       (- (point) (1+ calendar-day-digit-width)) (1- (point))
       `(mouse-face highlight help-echo ,(eval calendar-date-echo-text)
                    date t))
      (when (and (zerop (mod (+ day blank-days) 7))
                 (/= day last))
        (calendar-ensure-newline)
        (setq day (1+ day))       ; first day of next week
        (calendar-insert-at-column indent calendar-intermonth-text trunc)))))


;; setup
(taiwan-holidays-setup)

(provide 'taiwan-holidays)

;;; Local Variables: ***
;;; coding: utf-8 ***
;;; End: ***

;;; taiwan-holidays.el ends here
