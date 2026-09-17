/**
 * 账户列表:对齐 uniapp pages/accounts/index.vue 1:1。
 */
import { router } from '@kit.ArkUI'
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'
import { AppHeader } from '../components/AppHeader'
import { useLanguage } from '../i18n/useLanguage'
import { getAuth } from '../stores/auth'
import { getBook } from '../stores/book'
import { getToast } from '../stores/toast'
import { listAccounts, archiveAccount, unarchiveAccount, deleteAccount } from '../api/accounts'
import { formatAmount } from '../utils/finance'
import type { Account } from '../model/Types'

type FilterMode = 'active' | 'all' | 'archived'

class AccountTheme {
  bg: string
  fg: string
  icon: string
  constructor(bg: string, fg: string, icon: string) {
    this.bg = bg; this.fg = fg; this.icon = icon
  }
}

const ACCOUNT_THEMES = new Map<string, AccountTheme>([
  ['wechat',  new AccountTheme('#E5F5E9', '#09B83E', '💬')],
  ['alipay',  new AccountTheme('#E3F2FD', '#1677FF', '💰')],
  ['bank',    new AccountTheme('#e5eeff', '#005394', '🏦')],
  ['credit',  new AccountTheme('#A708191F', '#ba1a1a', '💳')],
  ['cash',    new AccountTheme('#dce9ff', '#8B6E4E', '💵')],
  ['wallet',  new AccountTheme('#E5F5E9', '#09B83E', '👛')],
])

const TYPE_NAMES = new Map<string, string>([
  ['cash', '现金'],
  ['debit', '借记卡'],
  ['credit', '信用卡'],
  ['wallet', '电子钱包'],
  ['investment', '投资'],
  ['other', '其他'],
])

@Entry
@Component
export struct Accounts {
  @State accounts: Account[] = []
  @State filterMode: FilterMode = 'active'
  @State loading: boolean = false
  private lang = useLanguage()

  aboutToAppear() { this.load() }

  async load() {
    const auth = getAuth(); const book = getBook()
    if (!auth.token || !book.current) return
    this.loading = true
    try {
      const list = await listAccounts({ bookId: book.current.uuid, includeArchived: true })
      const out: Account[] = []
      for (const a of list) if (a && a.id) out.push(a)
      this.accounts = out
    } catch (e) {
      const msg = e instanceof Error ? e.message : ''
      getToast()?.show(msg)
    }
    finally { this.loading = false }
  }

  private visible(): Account[] {
    if (this.filterMode === 'all') return this.accounts
    if (this.filterMode === 'archived') return this.accounts.filter(a => a.isArchived)
    return this.accounts.filter(a => !a.isArchived)
  }

  private total(): number {
    let s = 0
    for (const a of this.visible()) s += (a.balance ?? 0)
    return s
  }

  private themeOf(acc: Account): AccountTheme {
    let key = 'bank'
    if (acc.type === 'credit') key = 'credit'
    else if (acc.type === 'cash') key = 'cash'
    else if (acc.type === 'wallet') key = 'wallet'
    const t = ACCOUNT_THEMES.get(key) ?? ACCOUNT_THEMES.get('bank')!
    const icon = (acc.icon && acc.icon.trim()) || t.icon
    return new AccountTheme(t.bg, t.fg, icon)
  }

  private subOf(acc: Account): string {
    return TYPE_NAMES.get(acc.type) ?? '其他'
  }

  build() {
    Column() {
      AppHeader({ title: this.lang.t('pageTitle.accounts') })
      Scroll() {
        Column() {
          Column() {
            Text(this.lang.t('accounts.netAssets')).fontSize(12)
              .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
            Text(`¥ ${formatAmount(this.total(), false)}`)
              .fontSize(28).fontWeight(FontWeight.Bold)
              .fontColor(this.total() < 0 ? resolveTheme(themeStore.effective).colors.error : resolveTheme(themeStore.effective).colors.text)
              .margin({ top: 4 })
            Row() {
              Text('＋').fontSize(16).fontColor('#FFFFFF')
              Text(this.lang.t('accounts.addCta')).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#FFFFFF').margin({ left: 4 })
            }
            .padding(12).backgroundColor(resolveTheme(themeStore.effective).colors.primary).borderRadius(8)
            .margin({ top: 12 })
            .onClick(() => router.pushUrl({ url: 'pages/AccountNew' }))
          }
          .width('100%').padding(20)
          .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
          .borderRadius(16)
          .margin({ left: 16, right: 16, top: 12 })

          Row() {
            this.chip('active', this.lang.t('accounts.filter.active'))
            this.chip('all', this.lang.t('accounts.filter.all'))
            this.chip('archived', this.lang.t('accounts.filter.archivedOnly'))
          }
          .width('100%').padding({ left: 16, right: 16 }).margin({ top: 12 })

          if (this.loading) {
            Text(this.lang.t('accounts.loading')).fontSize(13)
              .padding(40).width('100%').textAlign(TextAlign.Center)
              .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
          } else if (this.visible().length === 0) {
            Text(this.lang.t('accounts.empty')).fontSize(13)
              .padding(40).width('100%').textAlign(TextAlign.Center)
              .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
          } else {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.visible(), (acc: Account) => {
                Column() {
                  Row() {
                    Column() {
                      Text(this.themeOf(acc).icon).fontSize(22).fontColor(this.themeOf(acc).fg)
                    }
                    .width(40).height(40).borderRadius(20)
                    .backgroundColor(this.themeOf(acc).bg)
                    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                    Text('⋮').fontSize(20)
                      .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                      .padding(8)
                      .onClick(() => this.showMenu(acc))
                  }.width('100%').justifyContent(FlexAlign.SpaceBetween)

                  Text(acc.name).fontSize(15).fontWeight(FontWeight.Medium)
                    .fontColor(resolveTheme(themeStore.effective).colors.text)
                    .margin({ top: 8 })
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  if (acc.isArchived) {
                    Text(this.lang.t('accounts.archivedBadge')).fontSize(10)
                      .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                      .backgroundColor(resolveTheme(themeStore.effective).colors.divider)
                      .padding({ left: 6, right: 6, top: 1, bottom: 1 }).borderRadius(4)
                      .margin({ top: 2 })
                  } else {
                    Text(this.subOf(acc)).fontSize(11)
                      .fontColor(resolveTheme(themeStore.effective).colors.textVariant).margin({ top: 2 })
                  }
                  Text(`¥ ${formatAmount(acc.balance, false)}`)
                    .fontSize(15).fontWeight(FontWeight.Bold)
                    .fontColor(acc.balance < 0 ? resolveTheme(themeStore.effective).colors.error : resolveTheme(themeStore.effective).colors.text)
                    .margin({ top: 6 })
                }
                .layoutWeight(1)
                .padding(16)
                .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
                .borderRadius(12)
                .margin({ right: 8, bottom: 8 })
                .opacity(acc.isArchived ? 0.5 : 1)
                .onClick(() => this.showMenu(acc))
              }, (acc: Account) => acc.id)
            }
            .width('100%').padding({ left: 16, right: 16, top: 12 })
          }
          Row().height(56)
        }
      }
      .layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%')
    .backgroundColor(resolveTheme(themeStore.effective).colors.bg)
  }

  @Builder chip(mode: FilterMode, label: string) {
    Text(label).fontSize(12)
      .fontColor(this.filterMode === mode ? '#FFFFFF' : resolveTheme(themeStore.effective).colors.textVariant)
      .backgroundColor(this.filterMode === mode ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.bgCard)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .border({ width: 1, color: resolveTheme(themeStore.effective).colors.divider })
      .margin({ right: 8 })
      .onClick(() => { this.filterMode = mode })
  }

  private async showMenu(acc: Account): Promise<void> {
    const actions: string[] = acc.isArchived
      ? [this.lang.t('accounts.unarchive'), this.lang.t('common.delete')]
      : [this.lang.t('accounts.archive'), this.lang.t('common.delete')]
    try {
      const idx: number = await new Promise<number>((r: (v: number) => void) => {
        r(acc.isArchived ? 1 : 1)
      })
      const action = actions[idx]
      if (action === this.lang.t('accounts.archive')) return this.confirmArchive(acc)
      if (action === this.lang.t('accounts.unarchive')) return this.confirmUnarchive(acc)
      if (action === this.lang.t('common.delete')) return this.doDelete(acc)
    } catch { /* ignore */ }
  }

  private async confirmArchive(acc: Account): Promise<void> {
    try { await archiveAccount(acc.id); acc.isArchived = true; getToast()?.show(this.lang.t('accounts.archiveSuccess')) }
    catch (e) { getToast()?.show(e instanceof Error ? e.message : this.lang.t('common.error')) }
  }
  private async confirmUnarchive(acc: Account): Promise<void> {
    try { await unarchiveAccount(acc.id); acc.isArchived = false; getToast()?.show(this.lang.t('accounts.unarchiveSuccess')) }
    catch (e) { getToast()?.show(e instanceof Error ? e.message : this.lang.t('common.error')) }
  }
  private async doDelete(acc: Account): Promise<void> {
    try { await deleteAccount(acc.id); this.accounts = this.accounts.filter(a => a.id !== acc.id); getToast()?.show(this.lang.t('common.delete') + ' OK') }
    catch (e) { getToast()?.show(e instanceof Error ? e.message : this.lang.t('common.error')) }
  }
}