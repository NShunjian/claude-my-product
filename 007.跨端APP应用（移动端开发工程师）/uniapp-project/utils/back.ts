/** History-aware 返回:有真实浏览器历史就 history.back(),否则去指定 tab 页。
 *  走 history.back 而不是 uni.navigateBack,因为后者在 H5 刷新后页栈空了会兜底
 *  reLaunch 到登录页 — 这是这次统一改造 custom nav 的根本目的。 */
export function goBack(fallbackTabUrl = '/pages/settings/index') {
  if (typeof window !== 'undefined' && window.history.length > 1) {
    window.history.back()
  } else {
    uni.switchTab({ url: fallbackTabUrl })
  }
}
