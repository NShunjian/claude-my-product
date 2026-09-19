/**
 * 主入口:tab 容器。
 * ponytail: 5 个 tab 用 Tabs 控件 + 子页面占位 Index 路由。
 */
import { router } from '@kit.ArkUI'
import { themeStore } from '../stores/theme'
import { languageStore } from '../stores/language'
import { authStore } from '../stores/auth'
import { bookStore } from '../stores/book'
import { setNavGrace } from '../api/http'
import { ApiError } from '../model/Types'
import { getTheme as resolveTheme } from '../theme/tokens'
import { ToastHost } from '../components/Toast'
import { Home } from './Home'
import { Transactions } from './Transactions'
import { Reports } from './Reports'
import { Accounts } from './Accounts'
import { Settings } from './Settings'
import { QuickAddModal } from '../components/QuickAddModal'
import { MonthPickerModal } from '../components/MonthPickerModal'
import { useLanguage } from '../i18n/useLanguage'

@Entry
@Component
struct Index {
  @State private currentIndex: number = 0
  private controller: TabsController = new TabsController()
  private lang = useLanguage()

  async aboutToAppear() {
    // 启动校验:hydrate → book hydrate → token 校验 → 数据预热
    await authStore.hydrate()
    await bookStore.hydrate()
    if (!authStore.token) {
      // 没 token → 登录页
      setNavGrace(3000)
      try { router.replaceUrl({ url: 'pages/Login' }) } catch { /* noop */ }
      return
    }
    // 有 token,验真(过期/无效 → 踢回登录页)
    try {
      await authStore.me()
      await bookStore.reload()
    } catch (e) {
      const code = e instanceof ApiError ? e.code : 0
      if (code === 1401 || code === 401) {
        // token 无效,兜底跳登录页(不依赖 kickToLogin 的 401 副作用)
        authStore.token = ''
        authStore.user = null
        await authStore.persist()
        setNavGrace(3000)
        try { router.replaceUrl({ url: 'pages/Login' }) } catch { /* noop */ }
      }
    }
  }

  @Builder TabBarBuilder() {
    Row() {
      this.tabItem(this.lang.t('tab.home'), $r('app.media.main_normal'), $r('app.media.main_select'), 0)
      this.tabItem(this.lang.t('tab.transactions'), $r('app.media.liushui_normal'), $r('app.media.liushui_select'), 1)
      this.tabItem(this.lang.t('tab.reports'), $r('app.media.baobiao_normal'), $r('app.media.baobiao_select'), 2)
      this.tabItem(this.lang.t('tab.accounts'), $r('app.media.zhanghu_normal'), $r('app.media.zhanghu_select'), 3)
      this.tabItem(this.lang.t('tab.settings'), $r('app.media.me_normal'), $r('app.media.me_select'), 4)
    }
    .width('100%').height(56)
    .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
    .border({ width: { top: 1 }, color: resolveTheme(themeStore.effective).colors.divider })
  }

  @Builder tabItem(label: string, normal: Resource, selected: Resource, idx: number) {
    Column() {
      Image(this.currentIndex === idx ? selected : normal)
        .width(24).height(24)
        .objectFit(ImageFit.Contain)
      Text(label).fontSize(11)
        .fontColor(this.currentIndex === idx ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.textVariant)
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => { this.currentIndex = idx; this.controller.changeIndex(idx) })
  }

  build() {
    Stack() {
      Tabs({ controller: this.controller }) {
        TabContent() { Home() }
        TabContent() { Transactions() }
        TabContent() { Reports() }
        TabContent() { Accounts() }
        TabContent() { Settings() }
      }
      .barHeight(0)
      .onChange((i: number) => { this.currentIndex = i })
      .width('100%').height('100%')

      Column() {
        Blank()
        this.TabBarBuilder()
      }
      .width('100%').height('100%')
      .hitTestBehavior(HitTestMode.Transparent)

      ToastHost()
      QuickAddModal()
      // MonthPickerModal:放在最顶层,覆盖整个屏幕包括底部 tabbar。
      MonthPickerModal()
    }
    .width('100%').height('100%')
    .backgroundColor(resolveTheme(themeStore.effective).colors.bg)
  }
}
