export const __webpack_esm_id__ = "extensionShared";
export const __webpack_esm_ids__ = ["extensionShared"];
export const __webpack_esm_modules__ = {

/***/ "./chrome/common/sanitise-filename.js":
/*!********************************************!*\
  !*** ./chrome/common/sanitise-filename.js ***!
  \********************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   HTML_FILE_EXTENSION: () => (/* binding */ HTML_FILE_EXTENSION),
/* harmony export */   buildSafeFilename: () => (/* binding */ buildSafeFilename)
/* harmony export */ });
/*************************************************************************
* ADOBE CONFIDENTIAL
* ___________________
*
*  Copyright 2026 Adobe Systems Incorporated
*  All Rights Reserved.
**************************************************************************/

/**
 * Shared filename sanitiser for HTML→PDF flows.
 * All surfaces that build a filename from `document.title` (or any untrusted
 * title-like string) and pass it to the Adobe Content Platform asset backend
 * must use this util — keeps sanitisation rules in one place.
 */

var MAX_ASSET_NAME_LENGTH = 240;
// Windows reserved device names — asset names cannot match these (case-insensitive),
// with the check applied to the part before the first dot.
var RESERVED_NAMES = /^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$/i;

/**
 * Sanitises a string for use as an Adobe Content Platform asset name.
 * See Asset Name Syntax: https://opensource.adobe.com/dc-acrobat-sdk-docs/cpsdk/syntax.html
 *  - Strips control characters (U+0000–U+001F, U+007F) and \ / : * ? " | < >
 *  - Disallows reserved device names (CON, PRN, AUX, NUL, COM[1-9], LPT[1-9])
 *  - Trims trailing whitespace and '.' characters
 *  - Enforces a 1..240 character length (reserving room for the extension)
 *  - If sanitisation wipes the title out entirely, falls back to a constant
 *    so we never send an empty filename to the backend.
 * @param {string} rawTitle - Untrusted title (e.g. document.title)
 * @param {string} extension - File extension to append, including the leading dot
 * @param {string} [fallbackFilename='webpage'] - Fallback name used when sanitisation yields an empty string
 * @returns {string} A filename safe for the repository backend
 */
var buildSafeFilename = function buildSafeFilename(rawTitle, extension) {
  var fallbackFilename = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : 'webpage';
  var sanitised = (rawTitle || '').toString()
  // eslint-disable-next-line no-control-regex
  .replace(/[\x00-\x1F\x7F<>:"/\\|?*]/g, '').replace(/\s+/g, ' ').trim()
  // Asset names cannot end with whitespace or '.' characters.
  .replace(/[.\s]+$/, '');

  // Guard against Windows reserved device names (check the part before the first dot).
  var firstSegment = sanitised.split('.')[0];
  if (firstSegment && RESERVED_NAMES.test(firstSegment)) {
    sanitised = "_".concat(sanitised);
  }

  // Reserve room for the extension within the 255-char asset name limit,
  // then re-trim so we don't end up with a trailing '.' or space.
  var maxBaseLen = Math.max(1, MAX_ASSET_NAME_LENGTH - extension.length);
  if (sanitised.length > maxBaseLen) {
    var cutAt = maxBaseLen;
    // Don't slice mid-surrogate-pair. If the last kept code unit is a high
    // surrogate (emoji/non-BMP char), drop it so we never emit a lone
    // surrogate that would break encodeURIComponent downstream.
    var lastCode = sanitised.charCodeAt(cutAt - 1);
    if (lastCode >= 0xD800 && lastCode <= 0xDBFF) {
      cutAt -= 1;
    }
    sanitised = sanitised.slice(0, cutAt).replace(/[.\s]+$/, '');
  }
  if (!sanitised) {
    sanitised = fallbackFilename;
  }
  return sanitised + extension;
};
var HTML_FILE_EXTENSION = '.html';

/***/ })

};

//# sourceMappingURL=extensionShared.js.map