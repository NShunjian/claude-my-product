/**
 * 新建账户:对齐 uniapp pages/accounts/new.vue 1:1。
 */
import { router } from '@kit.ArkUI'
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'
import { AppHeader } from '../components/AppHeader'
import { useLanguage } from '../i18n/useLanguage'
import { getBook } from '../stores/book'
import { getToast } from '../stores/toast'
import { createAccount } from '../api/accounts'
import type { AccountType } from '../model/Types'

interface AccountTypeOption { value: AccountType; label: string }

const ACCOUNT_TYPES: AccountTypeOption[] = [
  { value: 'wallet', label: '电子钱包' },
  { value: 'cash', label: '现金' },
  { value: 'debit', label: '银行卡' },
  { value: 'credit', label: '信用卡' },
  { value: 'investment', label: '投资账户' },
  { value: 'other', label: '其他' },
]
const ICONS: string[] = ['👛', '💳', '🏦', '💰', '📱']

@Entry
@Component
struct AccountNew {
  @State name: string = ''
  @State type: AccountType = 'wallet'
  @State balance: string = '0.00'
  @State icon: string = ICONS[0]
  @State isDefault: boolean = false
  @State submitting: boolean = false
  @State errorMsg: string | null = null
  private lang = useLanguage()

  private typeLabel(): string {
    for (let i = 0; i < ACCOUNT_TYPES.length; i++) {
      const t: AccountTypeOption = ACCOUNT_TYPES[i]
      if (t.value === this.type) return t.label
    }
    return this.lang.t('accountAdd.selectType')
  }

  async submit() {
    if (!this.name.trim() || !this.type) return
    const parsed = Number.parseFloat(this.balance)
    if (!Number.isFinite(parsed)) { this.errorMsg = '请输入有效的金额'; return }
    if (parsed > 999999999999.99) { this.errorMsg = '余额超出最大限制'; return }
    this.submitting = true
    try {
      await createAccount({
        name: this.name.trim(),
        type: this.type,
        icon: this.icon,
        initialBalance: parsed,
        currency: 'CNY',
        isDefault: this.isDefault,
      })
      router.back()
    } catch (e) {
      this.errorMsg = e instanceof Error ? (e.message || this.lang.t('accountAdd.saveFailPrefix')) : this.lang.t('accountAdd.saveFailPrefix')
    }
    finally { this.submitting = false }
  }

  build() {
    Column() {
      AppHeader({ title: this.lang.t('pageTitle.accountAdd'), back: true, onBack: () => router.back() })
      Scroll() {
        Column() {
          Column() {
            Column() {
              Text(this.lang.t('accountAdd.name')).fontSize(13).fontWeight(FontWeight.Medium)
              TextInput({ text: this.name, placeholder: this.lang.t('accountAdd.namePlaceholder') })
                .width('100%').height(48).padding({ left: 12, right: 12 })
                .backgroundColor(Color.Transparent).borderRadius(8)
                .border({ width: { bottom: 1 }, color: resolveTheme(themeStore.effective).colors.divider })
                .onChange((v: string) => { this.name = v })
            }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 16 })

            Column() {
              Text(this.lang.t('accountAdd.type')).fontSize(13).fontWeight(FontWeight.Medium)
              Row() {
                Text(this.typeLabel())
                  .layoutWeight(1).fontSize(14)
                Text('▼').fontSize(12)
                  .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
              }
              .width('100%').height(48).padding({ left: 12, right: 12 })
              .borderRadius(8)
              .border({ width: { bottom: 1 }, color: resolveTheme(themeStore.effective).colors.divider })
            }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 16 })

            Column() {
              Text(this.lang.t('accountAdd.balance')).fontSize(13).fontWeight(FontWeight.Medium)
              Row() {
                Text('¥').fontSize(16).margin({ right: 8 })
                TextInput({ text: this.balance, placeholder: '0.00' })
                  .type(InputType.Number)
                  .layoutWeight(1).fontSize(18)
                  .backgroundColor(Color.Transparent)
                  .onChange((v: string) => { this.balance = v })
              }
              .width('100%').height(48).padding({ left: 12, right: 12 })
              .borderRadius(8)
              .border({ width: { bottom: 1 }, color: resolveTheme(themeStore.effective).colors.divider })
            }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 16 })

            Column() {
              Text(this.lang.t('accountAdd.icon')).fontSize(13).fontWeight(FontWeight.Medium)
              Row() {
                ForEach(ICONS, (ic: string) => {
                  Column() {
                    Text(ic).fontSize(20)
                      .fontColor(this.icon === ic ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.textVariant)
                  }
                  .width(56).height(56).borderRadius(28)
                  .border({
                    width: 2,
                    color: this.icon === ic ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.divider,
                  })
                  .backgroundColor(this.icon === ic ? resolveTheme(themeStore.effective).colors.primaryLight : Color.Transparent)
                  .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                  .margin({ right: 8 })
                  .onClick(() => { this.icon = ic })
                }, (ic: string) => ic)
              }.margin({ top: 8 })
            }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 16 })

            Row() {
              Column() {
                Text(this.lang.t('accountAdd.isDefault')).fontSize(13).fontWeight(FontWeight.Medium)
                Text(this.lang.t('accountAdd.isDefaultHint')).fontSize(11)
                  .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                  .margin({ top: 2 })
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Toggle({ type: ToggleType.Switch, isOn: this.isDefault })
                .selectedColor(resolveTheme(themeStore.effective).colors.primary)
                .onChange((v: boolean) => { this.isDefault = v })
            }.width('100%').padding({ top: 12, bottom: 12 })
              .border({ width: { top: 1 }, color: resolveTheme(themeStore.effective).colors.divider })

            if (this.errorMsg) {
              Text(this.errorMsg).fontSize(13).fontColor('#C62828')
                .backgroundColor('#FFEBEE').padding(12).borderRadius(8)
                .width('100%').margin({ top: 12 })
            }

            Row() {
              Text(this.lang.t('accountAdd.cancel')).fontSize(15).layoutWeight(1).textAlign(TextAlign.Center)
                .padding(14).backgroundColor(resolveTheme(themeStore.effective).colors.surface)
                .borderRadius(8).margin({ right: 8 })
                .onClick(() => router.back())
              Text(this.submitting ? '…' : this.lang.t('accountAdd.submitAccount'))
                .fontSize(15).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                .layoutWeight(1).textAlign(TextAlign.Center)
                .padding(14).backgroundColor(resolveTheme(themeStore.effective).colors.primary)
                .borderRadius(8)
                .opacity(this.name.trim() ? 1 : 0.5)
                .onClick(() => this.submit())
            }.width('100%').margin({ top: 16 })
          }
          .width('100%').padding(20)
          .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
          .borderRadius(16)
        }
        .padding(16)
      }
      .layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%')
    .backgroundColor(resolveTheme(themeStore.effective).colors.bg)
  }
}