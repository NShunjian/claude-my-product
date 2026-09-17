/**
 * 主入口:tab 容器。
 * ponytail: 5 个 tab 用 Tabs 控件 + 子页面占位 Index 路由。
 */
import { themeStore } from '../stores/theme'
import { languageStore } from '../stores/language'
import { authStore } from '../stores/auth'
import { bookStore } from '../stores/book'
import { getTheme as resolveTheme } from '../theme/tokens'
import { ToastHost } from '../components/Toast'
import { Home } from './Home'
import { Transactions } from './Transactions'
import { Reports } from './Reports'
import { Accounts } from './Accounts'
import { Settings } from './Settings'
import { QuickAddModal } from '../components/QuickAddModal'
import { useLanguage } from '../i18n/useLanguage'

@Entry
@Component
struct Index {
  @State private currentIndex: number = 0
  private controller: TabsController = new TabsController()
  private lang = useLanguage()

  aboutToAppear() {
    // 初始化:启动时跑一次 token 校验 + book reload
    authStore.hydrate().then(async () => {
      bookStore.hydrate().then(async () => {
        if (authStore.token) {
          try { await authStore.me() } catch { /* silent */ }
          try { await bookStore.reload() } catch { /* silent */ }
        }
      })
    })
  }

  @Builder TabBarBuilder() {
    Row() {
      this.tabItem(this.lang.t('tab.home'), '🏠', 0)
      this.tabItem(this.lang.t('tab.transactions'), '📋', 1)
      this.tabItem(this.lang.t('tab.reports'), '📊', 2)
      this.tabItem(this.lang.t('tab.accounts'), '💳', 3)
      this.tabItem(this.lang.t('tab.settings'), '👤', 4)
    }
    .width('100%').height(56)
    .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
    .border({ width: { top: 1 }, color: resolveTheme(themeStore.effective).colors.divider })
  }

  @Builder tabItem(label: string, icon: string, idx: number) {
    Column() {
      Text(icon).fontSize(20)
        .fontColor(this.currentIndex === idx ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.textVariant)
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
    }
    .width('100%').height('100%')
    .backgroundColor(resolveTheme(themeStore.effective).colors.bg)
  }
}
