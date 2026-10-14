# Localization review

This file lists the riskiest strings of each language, for a native speaker to check. The rows from 26 on are the strings that the copy review of 2026-10-13 changed (D068). It covers the first release in six languages (D059). English is the source.

A reviewer checks three things in each row. The meaning of dose, time, skip, and taken stays the same. The text gives no medical advice. The text is short and natural, in the words of Apple's own apps in that language.

A string that names the iPhone has a second form for the iPad, with the same words and the other device name (D072). Check both forms. The full text is in `App/Localizable.xcstrings`, `Widget/Localizable.xcstrings`, `Watch/Localizable.xcstrings`, `App/InfoPlist.xcstrings`, and `Packages/MaruKit/Sources/MaruNotifications/Resources/Localizable.xcstrings`. To change a string, edit the catalog and keep the format specifiers (`%@`, `%lld`, `%1$@`). The reviewer's name and the date go in the table below after a check.

| Language | Reviewer | Date | Result |
|---|---|---|---|
| Simplified Chinese (zh-Hans) |  |  | Not reviewed |
| Japanese (ja) |  |  | Not reviewed |
| Spanish (es) |  |  | Not reviewed |
| German (de) |  |  | Not reviewed |
| Korean (ko) |  |  | Not reviewed |

## Simplified Chinese (zh-Hans)

| # | Area | Where | English | Translation |
|---|---|---|---|---|
| 1 | Notification | Title of a reminder | Time to take | 该服用了 |
| 2 | Notification | Title of a follow-up reminder | No record yet | 尚未记录 |
| 3 | Notification | Action of a reminder | Taken | 已服用 |
| 4 | Notification | Body with names off | Open Maru to see your plan. | 打开 Maru 查看你的计划。 |
| 5 | Notification | Title after the action recorded nothing | Not recorded | 未记录 |
| 6 | Notification | Body after the action recorded nothing | Open Maru to record it. | 打开 Maru 以记录。 |
| 8 | Dose wording | VoiceOver hint of a dose circle | Records it as taken. | 记录为已服用。 |
| 10 | Dose wording | Row text of a taken dose | Taken at %@ | %@ 服用 |
| 11 | Dose wording | State of a skipped dose | Skipped | 已跳过 |
| 12 | Dose wording | A planned dose with no record | No record | 无记录 |
| 13 | Dose wording | Action of an as-needed item | Record Dose | 记录服用 |
| 14 | Dose wording | Menu item: record at an earlier time | Taken Earlier… | 较早服用… |
| 15 | Alert | Delete confirmation | Maru deletes this item, its plan, and all its records. You can’t undo this. | Maru 会删除此项目、它的计划和所有记录。此操作无法撤销。 |
| 16 | Alert | Archive confirmation (not advice) | Maru stops its reminders and hides it from Today and My Items. Your records stay. This is not advice to stop taking it. | Maru 会停止它的提醒，并在“今天”和“我的项目”中隐藏它。你的记录会保留。这不是停止服用的建议。 |
| 17 | Alert | Restore confirmation | This backup replaces all items and records in Maru. You can’t undo this. | 此备份会替换 Maru 中的所有项目和记录。此操作无法撤销。 |
| 18 | Alert | Restore confirmation title | Replace Maru Data? | 要替换 Maru 数据吗？ |
| 19 | Alert | Restore not confirmed | Maru couldn’t confirm that your iPhone saved the restored data. If your data looks wrong later, restore the backup again. | Maru 无法确认 iPhone 是否已存储恢复的数据。如果之后发现数据有误，请再次恢复备份。 |
| 20 | Footer | Settings: backup files | A backup moves your items, records, and some settings to a new iPhone, but not photos. The files are not encrypted, so share them only with people you trust. | 备份可将项目、记录和部分设置迁移到新 iPhone，但不含照片。文件未加密，请只与你信任的人共享。 |
| 21 | Footer | Settings: usage statistics | Maru shares how you use the app, and never item names, doses, or times. | Maru 只共享功能使用情况，绝不包含项目名称、剂量或时间。 |
| 22 | Footer | Add and edit screen: limit of Until Recorded | Maru reminds you up to %lld times for each dose, until %@ at the latest. | 每次服用，Maru 最多提醒 %lld 次，最晚到 %@ 为止。 |
| 23 | Privacy notice | Notice outside the EU, the UK, and Switzerland | Maru shares how you use the app, such as whether you recorded a dose today. It never shares item names, doses, or times. You can turn this off in Settings. | Maru 会共享功能使用情况，例如今天是否记录了服用。绝不共享项目名称、剂量或时间。你可以随时在“设置”中关闭。 |
| 24 | Privacy notice | Notice in the EU, the UK, and Switzerland (opt-in) | Share how you use the app, such as whether you recorded a dose today. Maru never shares item names, doses, or times. You can change this in Settings. | 共享功能使用情况，例如今天是否记录了服用。Maru 绝不共享项目名称、剂量或时间。你可以随时在“设置”中更改。 |
| 25 | Permission | Camera permission prompt | Maru uses the camera to read the name on a label and to take a photo of an item. A label scan saves no photo. | Maru 使用相机读取标签上的名称，并为项目拍照。扫描标签不会存储照片。 |
| 26 | Alert | Restore not confirmed: title | Restore Not Confirmed | 恢复未确认 |
| 27 | Dose wording | Today and widgets: no dose planned today | Nothing Planned Today | 今天没有服用计划 |
| 28 | Footer | Add and edit screen: Remind Again | Only for doses with no record. | 仅提醒尚未记录的服用。 |
| 29 | Menu | Item detail: the menu of rarer changes | Item Options… | 项目选项… |
| 30 | Widget | VoiceOver label of an open dose | Not recorded | 未记录 |
| 31 | Widget | VoiceOver label of the count | %lld of %lld taken | 已服用 %1$lld/%2$lld |
| 32 | Footer | Item detail and alert: reminder not confirmed | Maru checks again when you open it. | 下次打开时，Maru 会再次检查。 |
| 33 | Footer | Item detail: reminder not set | Maru tries again when you open it. | 下次打开时，Maru 会再次尝试。 |

## Japanese (ja)

| # | Area | Where | English | Translation |
|---|---|---|---|---|
| 1 | Notification | Title of a reminder | Time to take | 服用の時間です |
| 2 | Notification | Title of a follow-up reminder | No record yet | まだ記録がありません |
| 3 | Notification | Action of a reminder | Taken | 服用済み |
| 4 | Notification | Body with names off | Open Maru to see your plan. | Maruを開いてプランを確認してください。 |
| 5 | Notification | Title after the action recorded nothing | Not recorded | 記録されていません |
| 6 | Notification | Body after the action recorded nothing | Open Maru to record it. | Maruを開いて記録してください。 |
| 8 | Dose wording | VoiceOver hint of a dose circle | Records it as taken. | 服用として記録します。 |
| 10 | Dose wording | Row text of a taken dose | Taken at %@ | %@に服用 |
| 11 | Dose wording | State of a skipped dose | Skipped | スキップ済み |
| 12 | Dose wording | A planned dose with no record | No record | 記録なし |
| 13 | Dose wording | Action of an as-needed item | Record Dose | 服用を記録 |
| 14 | Dose wording | Menu item: record at an earlier time | Taken Earlier… | 服用時刻を指定… |
| 15 | Alert | Delete confirmation | Maru deletes this item, its plan, and all its records. You can’t undo this. | Maruはこの項目、プラン、すべての記録を削除します。この操作は取り消せません。 |
| 16 | Alert | Archive confirmation (not advice) | Maru stops its reminders and hides it from Today and My Items. Your records stay. This is not advice to stop taking it. | Maruはこの項目のリマインドを止め、「今日」と「マイ項目」から非表示にします。記録は残ります。これは服用をやめるための助言ではありません。 |
| 17 | Alert | Restore confirmation | This backup replaces all items and records in Maru. You can’t undo this. | このバックアップは、Maruのすべての項目と記録を置き換えます。この操作は取り消せません。 |
| 18 | Alert | Restore confirmation title | Replace Maru Data? | Maruのデータを置き換えますか？ |
| 19 | Alert | Restore not confirmed | Maru couldn’t confirm that your iPhone saved the restored data. If your data looks wrong later, restore the backup again. | 復元したデータがiPhoneに保存されたか確認できませんでした。あとでデータがおかしい場合は、バックアップをもう一度復元してください。 |
| 20 | Footer | Settings: backup files | A backup moves your items, records, and some settings to a new iPhone, but not photos. The files are not encrypted, so share them only with people you trust. | バックアップを使うと、項目、記録、一部の設定を新しいiPhoneに移せます。写真は含まれません。ファイルは暗号化されていないため、信頼できる相手とだけ共有してください。 |
| 21 | Footer | Settings: usage statistics | Maru shares how you use the app, and never item names, doses, or times. | Maruが共有するのは機能の利用状況だけです。項目名、用量、時刻は共有しません。 |
| 22 | Footer | Add and edit screen: limit of Until Recorded | Maru reminds you up to %lld times for each dose, until %@ at the latest. | Maruは1回の服用につき最大%lld回、遅くとも%@までリマインドします。 |
| 23 | Privacy notice | Notice outside the EU, the UK, and Switzerland | Maru shares how you use the app, such as whether you recorded a dose today. It never shares item names, doses, or times. You can turn this off in Settings. | Maruは、今日服用を記録したかどうかなど、機能の利用状況を共有します。項目名、用量、時刻は共有しません。「設定」でいつでもオフにできます。 |
| 24 | Privacy notice | Notice in the EU, the UK, and Switzerland (opt-in) | Share how you use the app, such as whether you recorded a dose today. Maru never shares item names, doses, or times. You can change this in Settings. | 今日服用を記録したかどうかなど、機能の利用状況を共有します。項目名、用量、時刻は共有しません。「設定」でいつでも変更できます。 |
| 25 | Permission | Camera permission prompt | Maru uses the camera to read the name on a label and to take a photo of an item. A label scan saves no photo. | Maruはカメラを使って、ラベルの名前を読み取ったり、項目の写真を撮ったりします。ラベルのスキャンでは写真を保存しません。 |
| 26 | Alert | Restore not confirmed: title | Restore Not Confirmed | 復元を確認できません |
| 27 | Dose wording | Today and widgets: no dose planned today | Nothing Planned Today | 今日の服用予定はありません |
| 28 | Footer | Add and edit screen: Remind Again | Only for doses with no record. | まだ記録していない服用にだけ通知します。 |
| 29 | Menu | Item detail: the menu of rarer changes | Item Options… | 項目のオプション… |
| 30 | Widget | VoiceOver label of an open dose | Not recorded | 未記録 |
| 31 | Widget | VoiceOver label of the count | %lld of %lld taken | %2$lld回中%1$lld回服用 |
| 32 | Form | Item form: a liquid given in drops | Drops | 滴剤 |
| 33 | Form | Form proposal after a label scan | Use Drops | 滴剤にする |

## Spanish (es)

| # | Area | Where | English | Translation |
|---|---|---|---|---|
| 1 | Notification | Title of a reminder | Time to take | Hora de tomar |
| 2 | Notification | Title of a follow-up reminder | No record yet | Aún sin registro |
| 3 | Notification | Action of a reminder | Taken | Tomado |
| 4 | Notification | Body with names off | Open Maru to see your plan. | Abre Maru para ver tu plan. |
| 5 | Notification | Title after the action recorded nothing | Not recorded | No registrado |
| 6 | Notification | Body after the action recorded nothing | Open Maru to record it. | Abre Maru para registrarlo. |
| 8 | Dose wording | VoiceOver hint of a dose circle | Records it as taken. | La registra como tomada. |
| 10 | Dose wording | Row text of a taken dose | Taken at %@ | Tomado: %@ |
| 11 | Dose wording | State of a skipped dose | Skipped | Omitido |
| 12 | Dose wording | A planned dose with no record | No record | Sin registro |
| 13 | Dose wording | Action of an as-needed item | Record Dose | Registrar dosis |
| 14 | Dose wording | Menu item: record at an earlier time | Taken Earlier… | Tomado antes… |
| 15 | Alert | Delete confirmation | Maru deletes this item, its plan, and all its records. You can’t undo this. | Maru elimina este elemento, su plan y todos sus registros. No se puede deshacer. |
| 16 | Alert | Archive confirmation (not advice) | Maru stops its reminders and hides it from Today and My Items. Your records stay. This is not advice to stop taking it. | Maru detiene sus recordatorios y lo oculta de Hoy y de Mis elementos. Tus registros se conservan. Esto no es una recomendación de dejar de tomarlo. |
| 17 | Alert | Restore confirmation | This backup replaces all items and records in Maru. You can’t undo this. | Esta copia de seguridad reemplaza todos los elementos y registros de Maru. No se puede deshacer. |
| 18 | Alert | Restore confirmation title | Replace Maru Data? | ¿Reemplazar los datos de Maru? |
| 19 | Alert | Restore not confirmed | Maru couldn’t confirm that your iPhone saved the restored data. If your data looks wrong later, restore the backup again. | Maru no ha podido confirmar que el iPhone guardara los datos restaurados. Si más adelante tus datos parecen incorrectos, restaura la copia de seguridad otra vez. |
| 20 | Footer | Settings: backup files | A backup moves your items, records, and some settings to a new iPhone, but not photos. The files are not encrypted, so share them only with people you trust. | Una copia de seguridad traslada tus elementos, registros y algunos ajustes a un iPhone nuevo, pero no las fotos. Los archivos no están cifrados. Compártelos solo con personas de confianza. |
| 21 | Footer | Settings: usage statistics | Maru shares how you use the app, and never item names, doses, or times. | Maru comparte cómo usas la app, nunca nombres de elementos, dosis ni horas. |
| 22 | Footer | Add and edit screen: limit of Until Recorded | Maru reminds you up to %lld times for each dose, until %@ at the latest. | Maru te recuerda hasta %lld veces por dosis. Límite: %@. |
| 23 | Privacy notice | Notice outside the EU, the UK, and Switzerland | Maru shares how you use the app, such as whether you recorded a dose today. It never shares item names, doses, or times. You can turn this off in Settings. | Maru comparte cómo usas la app, por ejemplo si has registrado una dosis hoy. Nunca comparte nombres de elementos, dosis ni horas. Puedes desactivarlo en Ajustes. |
| 24 | Privacy notice | Notice in the EU, the UK, and Switzerland (opt-in) | Share how you use the app, such as whether you recorded a dose today. Maru never shares item names, doses, or times. You can change this in Settings. | Comparte cómo usas la app, por ejemplo si has registrado una dosis hoy. Maru nunca comparte nombres de elementos, dosis ni horas. Puedes cambiarlo en Ajustes. |
| 25 | Permission | Camera permission prompt | Maru uses the camera to read the name on a label and to take a photo of an item. A label scan saves no photo. | Maru usa la cámara para leer el nombre de una etiqueta y para hacer una foto de un elemento. El escaneo de una etiqueta no guarda ninguna foto. |
| 26 | Alert | Restore not confirmed: title | Restore Not Confirmed | Restauración sin confirmar |
| 27 | Dose wording | Today and widgets: no dose planned today | Nothing Planned Today | Nada planificado para hoy |
| 28 | Footer | Add and edit screen: Remind Again | Only for doses with no record. | Solo para las dosis sin registro. |
| 29 | Menu | Item detail: the menu of rarer changes | Item Options… | Opciones del elemento… |
| 30 | Widget | VoiceOver label of an open dose | Not recorded | Sin registrar |
| 31 | Widget | VoiceOver label of the count | %lld of %lld taken | %1$lld de %2$lld tomadas |

## German (de)

| # | Area | Where | English | Translation |
|---|---|---|---|---|
| 1 | Notification | Title of a reminder | Time to take | Zeit zur Einnahme |
| 2 | Notification | Title of a follow-up reminder | No record yet | Noch nicht erfasst |
| 3 | Notification | Action of a reminder | Taken | Eingenommen |
| 4 | Notification | Body with names off | Open Maru to see your plan. | Öffne Maru, um deinen Plan zu sehen. |
| 5 | Notification | Title after the action recorded nothing | Not recorded | Nicht erfasst |
| 6 | Notification | Body after the action recorded nothing | Open Maru to record it. | Öffne Maru, um es zu erfassen. |
| 8 | Dose wording | VoiceOver hint of a dose circle | Records it as taken. | Erfasst sie als eingenommen. |
| 10 | Dose wording | Row text of a taken dose | Taken at %@ | Eingenommen: %@ |
| 11 | Dose wording | State of a skipped dose | Skipped | Übersprungen |
| 12 | Dose wording | A planned dose with no record | No record | Keine Aufzeichnung |
| 13 | Dose wording | Action of an as-needed item | Record Dose | Dosis erfassen |
| 14 | Dose wording | Menu item: record at an earlier time | Taken Earlier… | Früher eingenommen … |
| 15 | Alert | Delete confirmation | Maru deletes this item, its plan, and all its records. You can’t undo this. | Maru löscht diesen Eintrag, seinen Plan und alle seine Aufzeichnungen. Das kannst du nicht rückgängig machen. |
| 16 | Alert | Archive confirmation (not advice) | Maru stops its reminders and hides it from Today and My Items. Your records stay. This is not advice to stop taking it. | Maru beendet seine Erinnerungen und blendet ihn in Heute und Meine Einträge aus. Deine Aufzeichnungen bleiben. Das ist keine Empfehlung, die Einnahme zu beenden. |
| 17 | Alert | Restore confirmation | This backup replaces all items and records in Maru. You can’t undo this. | Dieses Backup ersetzt alle Einträge und Aufzeichnungen in Maru. Das kannst du nicht rückgängig machen. |
| 18 | Alert | Restore confirmation title | Replace Maru Data? | Maru-Daten ersetzen? |
| 19 | Alert | Restore not confirmed | Maru couldn’t confirm that your iPhone saved the restored data. If your data looks wrong later, restore the backup again. | Maru konnte nicht bestätigen, dass dein iPhone die wiederhergestellten Daten gesichert hat. Wenn deine Daten später falsch aussehen, stelle das Backup erneut wieder her. |
| 20 | Footer | Settings: backup files | A backup moves your items, records, and some settings to a new iPhone, but not photos. The files are not encrypted, so share them only with people you trust. | Ein Backup überträgt deine Einträge, Aufzeichnungen und einige Einstellungen auf ein neues iPhone, aber keine Fotos. Die Dateien sind nicht verschlüsselt. Teile sie nur mit Personen, denen du vertraust. |
| 21 | Footer | Settings: usage statistics | Maru shares how you use the app, and never item names, doses, or times. | Maru teilt, wie du die App nutzt, aber nie Namen, Dosen oder Zeiten. |
| 22 | Footer | Add and edit screen: limit of Until Recorded | Maru reminds you up to %lld times for each dose, until %@ at the latest. | Maru erinnert dich bis zu %lld Mal pro Dosis, spätestens bis %@. |
| 23 | Privacy notice | Notice outside the EU, the UK, and Switzerland | Maru shares how you use the app, such as whether you recorded a dose today. It never shares item names, doses, or times. You can turn this off in Settings. | Maru teilt, wie du die App nutzt, zum Beispiel ob du heute eine Dosis erfasst hast. Maru teilt nie Namen, Dosen oder Zeiten. Du kannst das in den Einstellungen ausschalten. |
| 24 | Privacy notice | Notice in the EU, the UK, and Switzerland (opt-in) | Share how you use the app, such as whether you recorded a dose today. Maru never shares item names, doses, or times. You can change this in Settings. | Teile, wie du die App nutzt, zum Beispiel ob du heute eine Dosis erfasst hast. Maru teilt nie Namen, Dosen oder Zeiten. Du kannst das in den Einstellungen ändern. |
| 25 | Permission | Camera permission prompt | Maru uses the camera to read the name on a label and to take a photo of an item. A label scan saves no photo. | Maru verwendet die Kamera, um den Namen auf einem Etikett zu lesen und ein Foto eines Eintrags aufzunehmen. Ein Etikett-Scan speichert kein Foto. |
| 26 | Alert | Restore not confirmed: title | Restore Not Confirmed | Wiederherstellung nicht bestätigt |
| 27 | Dose wording | Today and widgets: no dose planned today | Nothing Planned Today | Heute nichts geplant |
| 28 | Footer | Add and edit screen: Remind Again | Only for doses with no record. | Nur für Dosen ohne Aufzeichnung. |
| 29 | Menu | Item detail: the menu of rarer changes | Item Options… | Eintragsoptionen … |
| 30 | Widget | VoiceOver label of an open dose | Not recorded | Nicht erfasst |
| 31 | Widget | VoiceOver label of the count | %lld of %lld taken | %1$lld von %2$lld eingenommen |

## Korean (ko)

| # | Area | Where | English | Translation |
|---|---|---|---|---|
| 1 | Notification | Title of a reminder | Time to take | 복용할 시간 |
| 2 | Notification | Title of a follow-up reminder | No record yet | 아직 기록이 없어요 |
| 3 | Notification | Action of a reminder | Taken | 복용함 |
| 4 | Notification | Body with names off | Open Maru to see your plan. | Maru를 열어 계획을 확인하세요. |
| 5 | Notification | Title after the action recorded nothing | Not recorded | 기록되지 않음 |
| 6 | Notification | Body after the action recorded nothing | Open Maru to record it. | Maru를 열어 기록하세요. |
| 8 | Dose wording | VoiceOver hint of a dose circle | Records it as taken. | 복용함으로 기록해요. |
| 10 | Dose wording | Row text of a taken dose | Taken at %@ | 복용 시간: %@ |
| 11 | Dose wording | State of a skipped dose | Skipped | 건너뜀 |
| 12 | Dose wording | A planned dose with no record | No record | 기록 없음 |
| 13 | Dose wording | Action of an as-needed item | Record Dose | 복용 기록 |
| 14 | Dose wording | Menu item: record at an earlier time | Taken Earlier… | 앞서 복용함… |
| 15 | Alert | Delete confirmation | Maru deletes this item, its plan, and all its records. You can’t undo this. | Maru가 이 항목과 계획, 모든 기록을 삭제해요. 이 동작은 되돌릴 수 없어요. |
| 16 | Alert | Archive confirmation (not advice) | Maru stops its reminders and hides it from Today and My Items. Your records stay. This is not advice to stop taking it. | Maru가 이 항목의 미리 알림을 멈추고 오늘과 내 항목에서 숨겨요. 기록은 그대로 남아요. 복용을 멈추라는 조언이 아니에요. |
| 17 | Alert | Restore confirmation | This backup replaces all items and records in Maru. You can’t undo this. | 이 백업은 Maru의 모든 항목과 기록을 교체해요. 이 동작은 되돌릴 수 없어요. |
| 18 | Alert | Restore confirmation title | Replace Maru Data? | Maru 데이터를 교체할까요? |
| 19 | Alert | Restore not confirmed | Maru couldn’t confirm that your iPhone saved the restored data. If your data looks wrong later, restore the backup again. | 복원한 데이터가 iPhone에 저장되었는지 확인하지 못했어요. 나중에 데이터가 이상하면 백업을 다시 복원하세요. |
| 20 | Footer | Settings: backup files | A backup moves your items, records, and some settings to a new iPhone, but not photos. The files are not encrypted, so share them only with people you trust. | 백업하면 항목, 기록, 일부 설정을 새 iPhone으로 옮길 수 있어요. 사진은 포함되지 않아요. 파일은 암호화되지 않으니 믿을 수 있는 사람과만 공유하세요. |
| 21 | Footer | Settings: usage statistics | Maru shares how you use the app, and never item names, doses, or times. | Maru는 앱 사용 정보만 공유해요. 항목 이름, 용량, 시간은 절대 공유하지 않아요. |
| 22 | Footer | Add and edit screen: limit of Until Recorded | Maru reminds you up to %lld times for each dose, until %@ at the latest. | Maru는 복용 1회당 최대 %lld번, 늦어도 %@까지 미리 알려줘요. |
| 23 | Privacy notice | Notice outside the EU, the UK, and Switzerland | Maru shares how you use the app, such as whether you recorded a dose today. It never shares item names, doses, or times. You can turn this off in Settings. | Maru는 오늘 복용을 기록했는지 같은 앱 사용 정보를 공유해요. 항목 이름, 용량, 시간은 절대 공유하지 않아요. 설정에서 언제든 끌 수 있어요. |
| 24 | Privacy notice | Notice in the EU, the UK, and Switzerland (opt-in) | Share how you use the app, such as whether you recorded a dose today. Maru never shares item names, doses, or times. You can change this in Settings. | 오늘 복용을 기록했는지 같은 앱 사용 정보를 공유해요. 항목 이름, 용량, 시간은 절대 공유하지 않아요. 설정에서 언제든 바꿀 수 있어요. |
| 25 | Permission | Camera permission prompt | Maru uses the camera to read the name on a label and to take a photo of an item. A label scan saves no photo. | Maru는 카메라로 라벨의 이름을 읽고 항목 사진을 찍어요. 라벨 스캔은 사진을 저장하지 않아요. |
| 26 | Alert | Restore not confirmed: title | Restore Not Confirmed | 복원이 확인되지 않음 |
| 27 | Dose wording | Today and widgets: no dose planned today | Nothing Planned Today | 오늘 예정된 복용 없음 |
| 28 | Footer | Add and edit screen: Remind Again | Only for doses with no record. | 아직 기록하지 않은 복용에만 와요. |
| 29 | Menu | Item detail: the menu of rarer changes | Item Options… | 항목 옵션… |
| 30 | Widget | VoiceOver label of an open dose | Not recorded | 기록되지 않음 |
| 31 | Widget | VoiceOver label of the count | %lld of %lld taken | %2$lld회 중 %1$lld회 복용함 |
| 32 | Form | Item form: a liquid given in drops | Drops | 점적제 |
| 33 | Form | Form proposal after a label scan | Use Drops | 점적제 사용 |
| 34 | History | Correction of a time | Time changed to %@ | 변경된 시간: %@ |
| 35 | Footer | Item detail: every-other-day plan | Maru sets the reminders of the next 7 dose days each time you open it. | Maru를 열 때마다 다음 7번의 복용일에 맞춰 미리 알림을 설정해요. |

## Name lists (D070)

The name suggestions of each language come from `App/Resources/SupplementNames-<language>.txt` and `App/Resources/MedicationNames-<language>.txt`. A native speaker checks each list: the names are the names that people in that market use and see on labels, the spelling is the usual one, no name is a brand, and no alias leads to another medicine. The debug sample data in `App/DebugLaunch.swift` has six names and dose words per language. The names in the table are the ones the author is least sure of.

A first review on 2026-10-13 corrected the entries below. Every name, alias, and twin still needs a check by a native pharmacist, also the corrected ones.

| Language | Supplements | Medicines | Check first |
|---|---|---|---|
| zh-Hans | 176 | 247 | 氮泵, 增肌粉, 大麦若叶, 黑芝麻丸, 维生素AD as a medicine, the aliases 扑热息痛, 坦洛新, 扑尔敏, 黄连素, 多种维生素, 维生素 B 族, 水飞蓟, 玻尿酸 |
| ja | 183 | 219 | 正露丸 (brand or generic), メラトニン as a medicine, 酵素, カテキン, ビタミンD&K2 with no English twin, シリカ and こんにゃく as their own entries, 非変性II型コラーゲン, ボラージオイル, 銀翹散, the readings of the Kampo names |
| ko | 166 | 198 | 프리워크아웃 with 운동전 부스터, 유단백가수분해물, 미역 등 복합추출물, 프랑스해안송껍질추출물, 트리메타지딘, 오메가-3-산에틸에스테르90, 감마리놀렌산 and 달맞이꽃 종자유 as two entries, 녹즙 and 킬레이트 철분 with no English twin, 흑염소 진액, the dose words 1캡슐 and 1정 |
| es | 165 | 210 | Pre-entreno, Omega 3-6-9, Tila, Extracto de té verde, Butilbromuro de hioscina as an alias of Butilescopolamina, the dose word "cápsula blanda" for a softgel |
| de | 167 | 215 | Greens-Pulver, Pre-Workout with the alias Pre-Workout-Booster, OPC and Traubenkernextrakt as two entries, Silizium and Kieselerde as two entries, Meerwasser-Nasenspray, Kurkuma mit Piperin |
