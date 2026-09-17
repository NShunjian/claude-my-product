/**
 * 账本列表:对齐 uniapp pages/books/index.vue 1:1。
 */
import { router } from '@kit.ArkUI'
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'
import { AppHeader } from '../components/AppHeader'
import { useLanguage } from '../i18n/useLanguage'
import { getToast } from '../stores/toast'
import { bookStore } from '../stores/book'
import { setPendingBookUuid } from '../utils/nav-intent'
import { listBooks, createBook, updateBook, deleteBook } from '../api/books'
import type { Book, BookType } from '../model/Types'
import { I18nArgs } from '../i18n/dict'

interface BookTypeOption { value: BookType; label: string }

const TYPE_OPTIONS: BookTypeOption[] = [
  { value: 'personal', label: '个人' },
  { value: 'shared', label: '共享' },
  { value: 'business', label: '生意' },
]

@Entry
@Component
struct Books {
  @State books: Book[] = []
  @State showCreate: boolean = false
  @State newName: string = ''
  @State newType: BookType = 'personal'
  @State newDesc: string = ''
  @State editing: Book | null = null
  @State editDesc: string = ''
  @State busy: boolean = false
  private lang = useLanguage()

  aboutToAppear() { this.load() }

  async load() {
    try { this.books = await listBooks() } catch (e) {
      getToast()?.show(e instanceof Error ? (e.message ?? '') : '')
    }
  }

  private async create() {
    if (!this.newName.trim()) return
    this.busy = true
    try {
      await createBook({ name: this.newName.trim(), type: this.newType, description: this.newDesc.trim() || undefined })
      this.showCreate = false
      this.newName = ''; this.newDesc = ''; this.newType = 'personal'
      getToast()?.show(this.lang.t('books.create.success'))
      await this.load()
    } catch (e) {
      const msg = e instanceof Error ? (e.message ?? '') : ''
      getToast()?.show(this.lang.t('books.create.failPrefix') + msg)
    }
    finally { this.busy = false }
  }

  private async switchTo(uuid: string) {
    try {
      await bookStore.setCurrent(uuid)
      getToast()?.show(this.lang.t('books.action.switch') + ' OK')
    } catch (e) {
      const msg = e instanceof Error ? (e.message ?? '') : ''
      getToast()?.show(this.lang.t('books.switch.failPrefix') + msg)
    }
  }

  private openEdit(b: Book) { this.editing = b; this.editDesc = b.description ?? '' }

  private async saveEdit() {
    if (!this.editing) return
    this.busy = true
    try {
      await updateBook(this.editing.uuid, { description: this.editDesc.trim() || null })
      this.editing = null
      getToast()?.show(this.lang.t('books.edit.success'))
      await this.load()
    } catch (e) {
      const msg = e instanceof Error ? (e.message ?? '') : ''
      getToast()?.show(this.lang.t('books.edit.failPrefix') + msg)
    }
    finally { this.busy = false }
  }

  private async del(b: Book) {
    try {
      await deleteBook(b.uuid)
      getToast()?.show(this.lang.t('books.delete.success'))
      await this.load()
    } catch (e) {
      const msg = e instanceof Error ? (e.message ?? '') : ''
      getToast()?.show(this.lang.t('books.delete.failPrefix') + msg)
    }
  }

  private typeIcon(t: BookType): string {
    return t === 'shared' ? 'group' : t === 'business' ? 'business_center' : 'person'
  }

  build() {
    Stack() {
      Column() {
        AppHeader({
          title: this.lang.t('books.heading'),
          right: this.rightBuilder,
        })
        Scroll() {
          Column() {
            if (this.showCreate) {
              Column() {
                Text(this.lang.t('books.create.title')).fontSize(16).fontWeight(FontWeight.Bold)
                  .margin({ bottom: 12 })
                Text(this.lang.t('books.create.name')).fontSize(12).margin({ bottom: 4 })
                TextInput({ text: this.newName, placeholder: this.lang.t('books.create.namePlaceholder') })
                  .width('100%').height(44).padding(12)
                  .backgroundColor(resolveTheme(themeStore.effective).colors.surface).borderRadius(8)
                  .onChange((v: string) => { this.newName = v })
                Text(this.lang.t('books.create.type')).fontSize(12).margin({ top: 12, bottom: 4 })
                Scroll() {
                  Row() {
                    ForEach(TYPE_OPTIONS, (o: BookTypeOption) => {
                      Text(o.label).fontSize(12)
                        .fontColor(this.newType === o.value ? '#FFFFFF' : resolveTheme(themeStore.effective).colors.text)
                        .backgroundColor(this.newType === o.value ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.surface)
                        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                        .borderRadius(16).margin({ right: 8 })
                        .onClick(() => { this.newType = o.value })
                    }, (o: BookTypeOption) => o.value)
                  }
                }
                .scrollable(ScrollDirection.Horizontal).width('100%')
                Text(this.lang.t('books.create.description')).fontSize(12).margin({ top: 12, bottom: 4 })
                TextInput({ text: this.newDesc, placeholder: this.lang.t('books.create.descPlaceholder') })
                  .width('100%').height(44).padding(12)
                  .backgroundColor(resolveTheme(themeStore.effective).colors.surface).borderRadius(8)
                  .onChange((v: string) => { this.newDesc = v })
                Row() {
                  Text(this.lang.t('common.cancel')).fontSize(14).layoutWeight(1).textAlign(TextAlign.Center)
                    .padding(12).backgroundColor(resolveTheme(themeStore.effective).colors.surface)
                    .borderRadius(8).margin({ right: 8 })
                    .onClick(() => { this.showCreate = false })
                  Text(this.busy ? '…' : this.lang.t('common.save')).fontSize(14).fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF').layoutWeight(1).textAlign(TextAlign.Center)
                    .padding(12).backgroundColor(resolveTheme(themeStore.effective).colors.primary)
                    .borderRadius(8)
                    .opacity(this.newName.trim() ? 1 : 0.5)
                    .onClick(() => this.create())
                }.width('100%').margin({ top: 16 })
              }
              .width('100%').padding(16).margin({ left: 16, right: 16, top: 12 })
              .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard).borderRadius(16)
            }

            if (this.books.length === 0) {
              Text(this.lang.t('books.empty')).fontSize(13).padding(40).width('100%').textAlign(TextAlign.Center)
                .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
            } else {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.books, (b: Book) => {
                  Column() {
                    Row() {
                      Column() {
                        Text(b.name).fontSize(15).fontWeight(FontWeight.Bold)
                          .fontColor(resolveTheme(themeStore.effective).colors.text)
                        Text(b.description || this.lang.t('books.noDesc')).fontSize(11)
                          .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                          .margin({ top: 2 })
                          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                      if (b.isDefault) {
                        Text(this.lang.t('books.badge.default')).fontSize(10)
                          .fontColor(resolveTheme(themeStore.effective).colors.primary)
                          .backgroundColor(resolveTheme(themeStore.effective).colors.primaryLight)
                          .padding({ left: 6, right: 6, top: 1, bottom: 1 }).borderRadius(4)
                      }
                    }.width('100%')
                    Row() {
                      Text(this.typeIcon(b.type) === 'group' ? '👥' : b.type === 'business' ? '💼' : '👤').fontSize(11)
                      Text(` ${this.lang.t(`books.type.${b.type}`)}`).fontSize(11)
                        .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                      Text(' · ').fontSize(11).fontColor(resolveTheme(themeStore.effective).colors.divider)
                      Text(this.lang.t(`books.role.${b.role ?? 'owner'}`)).fontSize(11)
                        .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                    }.margin({ top: 4 })
                    Row() {
                      if (bookStore.currentId !== b.uuid) {
                        Text(this.lang.t('books.action.switch')).fontSize(11)
                          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                          .border({ width: 1, color: resolveTheme(themeStore.effective).colors.primary })
                          .borderRadius(4).fontColor(resolveTheme(themeStore.effective).colors.primary)
                          .margin({ right: 4 })
                          .onClick(() => this.switchTo(b.uuid))
                      } else {
                        Text(this.lang.t('books.badge.current')).fontSize(11).fontWeight(FontWeight.Medium)
                          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                          .backgroundColor(resolveTheme(themeStore.effective).colors.primaryLight)
                          .borderRadius(4).fontColor(resolveTheme(themeStore.effective).colors.primary)
                          .margin({ right: 4 })
                      }
                      Text(this.lang.t('books.action.members')).fontSize(11)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                        .border({ width: 1, color: resolveTheme(themeStore.effective).colors.primary })
                        .borderRadius(4).fontColor(resolveTheme(themeStore.effective).colors.primary)
                        .margin({ right: 4 })
                        .onClick(() => {
                          setPendingBookUuid(b.uuid)
                          router.pushUrl({ url: 'pages/BookMembers' })
                        })
                      if (b.role === 'owner') {
                        Text(this.lang.t('common.edit')).fontSize(11)
                          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                          .border({ width: 1, color: resolveTheme(themeStore.effective).colors.primary })
                          .borderRadius(4).fontColor(resolveTheme(themeStore.effective).colors.primary)
                          .margin({ right: 4 })
                          .onClick(() => this.openEdit(b))
                      }
                      if (b.role === 'owner' && !b.isDefault) {
                        Text(this.lang.t('common.delete')).fontSize(11)
                          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                          .border({ width: 1, color: resolveTheme(themeStore.effective).colors.error })
                          .borderRadius(4).fontColor(resolveTheme(themeStore.effective).colors.error)
                          .onClick(() => this.del(b))
                      }
                    }.width('100%').margin({ top: 8 })
                  }
                  .layoutWeight(1)
                  .padding(12).margin({ right: 6, bottom: 8 })
                  .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard).borderRadius(12)
                  .border({
                    width: bookStore.currentId === b.uuid ? 2 : 1,
                    color: bookStore.currentId === b.uuid ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.divider,
                  })
                }, (b: Book) => b.uuid)
              }
              .width('100%').padding({ left: 16, right: 16, top: 12 })
            }
          }
        }
        .layoutWeight(1).scrollBar(BarState.Off)
      }
      .width('100%').height('100%')
      .backgroundColor(resolveTheme(themeStore.effective).colors.bg)

      if (this.editing) {
        Stack() {
          Column().width('100%').height('100%').backgroundColor('#00000066')
            .onClick(() => { this.editing = null })
          Column() {
            Text(this.lang.t('books.edit.title', new I18nArgs('name', this.editing.name))).fontSize(16).fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
            Text(this.lang.t('books.create.description')).fontSize(12).margin({ bottom: 4 })
            TextInput({ text: this.editDesc }).width('100%').height(44).padding(12)
              .backgroundColor(resolveTheme(themeStore.effective).colors.surface).borderRadius(8)
              .onChange((v: string) => { this.editDesc = v })
            Row() {
              Text(this.lang.t('common.cancel')).fontSize(14).layoutWeight(1).textAlign(TextAlign.Center)
                .padding(12).backgroundColor(resolveTheme(themeStore.effective).colors.surface)
                .borderRadius(8).margin({ right: 8 })
                .onClick(() => { this.editing = null })
              Text(this.lang.t('common.save')).fontSize(14).fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF').layoutWeight(1).textAlign(TextAlign.Center)
                .padding(12).backgroundColor(resolveTheme(themeStore.effective).colors.primary)
                .borderRadius(8)
                .onClick(() => this.saveEdit())
            }.width('100%').margin({ top: 16 })
          }
          .width('80%').padding(20)
          .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard).borderRadius(16)
        }
        .width('100%').height('100%').position({ x: 0, y: 0 })
      }
    }
    .width('100%').height('100%')
  }

  @Builder rightBuilder() {
    Text(`+ ${this.lang.t('books.create.toggle')}`).fontSize(13).fontWeight(FontWeight.Medium)
      .fontColor('#FFFFFF')
      .backgroundColor(resolveTheme(themeStore.effective).colors.primary)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(8)
      .onClick(() => { this.showCreate = !this.showCreate })
  }
}