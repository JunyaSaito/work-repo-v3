// 共通ユーティリティ

/** 0-based列インデックスをA,B,...,Z,AA,...形式に変換 */
function colLetter(index) {
  let s = "";
  let i = index;
  while (i >= 0) {
    s = String.fromCharCode(65 + (i % 26)) + s;
    i = Math.floor(i / 26) - 1;
  }
  return s;
}

module.exports = { colLetter };
