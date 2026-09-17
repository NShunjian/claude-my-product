/**
 * 记一笔 - 收入页。
 */
import { router } from '@kit.ArkUI'
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'
import { AppHeader } from '../components/AppHeader'
import { RecordForm } from '../components/RecordForm'
import { useLanguage } from '../i18n/useLanguage'
import { getToast } from '../stores/toast'
import { getBook } from '../stores/book'
import { listAccounts } from '../api/accounts'
import { listCategories } from '../api/categories'
import { createRecord } from '../api/records'
import type { Account, Category, RecordCreatePayload } from '../model/Types'

@Entry
@Component
struct RecordIncome {
  @State accounts: Account[] = []
  @State expenseCats: Category[] = []
  @State incomeCats: Category[] = []
  private lang = useLanguage()

  aboutToAppear() { this.load() }

  async load() {
    const book = getBook()
    if (!book.current) return
    try {
      const res = await Promise.all([
        listAccounts({ bookId: book.current.uuid }),
        listCategories('expense'),
        listCategories('income'),
      ])
      this.accounts = res[0]; this.expenseCats = res[1]; this.incomeCats = res[2]
    } catch (e) {
      const msg = e instanceof Error ? (e.message ?? '') : ''
      getToast()?.show(msg)
    }
  }

  private async submit(payload: RecordCreatePayload): Promise<void> {
    try {
      await createRecord(payload)
      getToast()?.show(this.lang.t('record.saveSuccess'))
      router.back()
    } catch (e) {
      const msg = e instanceof Error ? (e.message ?? '') : ''
      getToast()?.show(msg || this.lang.t('record.saveFail'))
    }
  }

  private handleSubmit(d: RecordCreatePayload): void { void this.submit(d) }

  build() {
    Column() {
      AppHeader({ title: this.lang.t('pageTitle.recordIncome'), back: true, onBack: () => router.back() })
      Scroll() {
        RecordForm({
          type: 'income',
          accounts: this.accounts,
          expenseCats: this.expenseCats,
          incomeCats: this.incomeCats,
          onSubmit: this.handleSubmit.bind(this),
          onCancel: () => router.back(),
        })
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%').height('100%')
    .backgroundColor(resolveTheme(themeStore.effective).colors.bg)
  }
}