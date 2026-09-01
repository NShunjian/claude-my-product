/** History-aware 返回:有真实浏览器历史就 history.back(),否则整页跳到指定 tab 页。
 *  不用 uni.navigateBack(H5 刷新后页栈空了会兜底 reLaunch 登录页),
 *  不用 uni.switchTab(内部会先 reLaunch 到 pages.json[0] 再切目标,中间闪一下 login),
 *  直接 location.replace 绕过 uniapp Router — 代价是一次白屏,但稳定可预期。 */
export function goBack(fallbackTabUrl = '/pages/settings/index') {
  if (typeof window !== 'undefined' && window.history.length > 1) {
    window.history.back()
  } else if (typeof window !== 'undefined') {
    window.location.replace(fallbackTabUrl)
  } else {
    uni.switchTab({ url: fallbackTabUrl })
  }
}
