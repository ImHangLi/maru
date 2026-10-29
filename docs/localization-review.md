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
| 6 | Notification | Body after the action recorded nothing, no match with one dose (D089) | This reminder no longer matches one dose of today. Open Maru to record it. | 这条提醒已不对应今天的某一次服用。打开 Maru 来记录。 |
| 7 | Notification | Body after the action recorded nothing, record not saved (D089) | Maru could not save the dose. Open Maru to try again. | Maru 没能保存这次记录。打开 Maru 再试一次。 |
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
| 6 | Notification | Body after the action recorded nothing, no match with one dose (D089) | This reminder no longer matches one dose of today. Open Maru to record it. | このリマインダーは、今日の1回分と一致しなくなりました。Maruを開いて記録してください。 |
| 7 | Notification | Body after the action recorded nothing, record not saved (D089) | Maru could not save the dose. Open Maru to try again. | Maruは記録を保存できませんでした。Maruを開いてもう一度お試しください。 |
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
| 6 | Notification | Body after the action recorded nothing, no match with one dose (D089) | This reminder no longer matches one dose of today. Open Maru to record it. | Este recordatorio ya no corresponde a una sola toma de hoy. Abre Maru para registrarla. |
| 7 | Notification | Body after the action recorded nothing, record not saved (D089) | Maru could not save the dose. Open Maru to try again. | Maru no pudo guardar la toma. Abre Maru para intentarlo de nuevo. |
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
| 6 | Notification | Body after the action recorded nothing, no match with one dose (D089) | This reminder no longer matches one dose of today. Open Maru to record it. | Diese Erinnerung passt nicht mehr zu genau einer Einnahme von heute. Öffne Maru, um sie zu erfassen. |
| 7 | Notification | Body after the action recorded nothing, record not saved (D089) | Maru could not save the dose. Open Maru to try again. | Maru konnte die Einnahme nicht speichern. Öffne Maru und versuche es erneut. |
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
| 6 | Notification | Body after the action recorded nothing, no match with one dose (D089) | This reminder no longer matches one dose of today. Open Maru to record it. | 이 알림은 더 이상 오늘의 한 회분과 맞지 않습니다. Maru를 열어 기록해 주세요. |
| 7 | Notification | Body after the action recorded nothing, record not saved (D089) | Maru could not save the dose. Open Maru to try again. | Maru가 기록을 저장하지 못했습니다. Maru를 열어 다시 시도해 주세요. |
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

## Reminder actions (D090)

The eight strings below are new in `Packages/MaruKit/Sources/MaruNotifications/Resources/Localizable.xcstrings`. They are the buttons of a reminder and two notices. No native speaker read them. The reviewer checks the same three things as above, and that the buttons fit on one line of a lock screen notification.

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Take All | 全部已服用 | すべて服用済み | Todo tomado | Alle eingenommen | 모두 복용함 |
| Skip | 跳过 | スキップ | Omitir | Überspringen | 건너뛰기 |
| Skip All | 全部跳过 | すべてスキップ | Omitir todo | Alle überspringen | 모두 건너뛰기 |
| Remind in 10 min | 10分钟后提醒 | 10分後に再通知 | Recordar en 10 min | In 10 Min. erinnern | 10분 후 다시 알림 |
| Partly recorded | 部分已记录 | 一部のみ記録 | Registrado en parte | Teilweise erfasst | 일부만 기록됨 |
| %lld of %lld recorded. Open Maru to check the rest. | 已记录 %lld/%lld 项。打开 Maru 看看其余的。 | %lld/%lld件を記録しました。残りはMaruを開いて確認してください。 | %lld de %lld registradas. Abre Maru para revisar el resto. | %lld von %lld erfasst. Öffne Maru, um den Rest zu prüfen. | %lld/%lld개를 기록했습니다. Maru를 열어 나머지를 확인해 주세요. |
| Reminder not set | 没能设置提醒 | リマインダーを設定できませんでした | Recordatorio no programado | Erinnerung nicht gesetzt | 알림을 설정하지 못했습니다 |
| This reminder no longer matches a dose of today. Open Maru to see your plan. | 这条提醒已不对应今天的任何一次服用。打开 Maru 查看你的计划。 | このリマインダーは、今日の記録と一致しなくなりました。Maruを開いて予定を確認してください。 | Este recordatorio ya no corresponde a una toma de hoy. Abre Maru para ver tu plan. | Diese Erinnerung passt nicht mehr zu einer Einnahme von heute. Öffne Maru, um deinen Plan zu sehen. | 이 알림은 더 이상 오늘의 복용과 맞지 않습니다. Maru를 열어 계획을 확인해 주세요. |

## Warm voice (D101)

The strings below are new or changed in `App/Localizable.xcstrings`. They are drafts. No native speaker read them. The reviewer checks the same three things as above. The tone is warm and calm, like a reliable friend: polite but friendly in ja and ko, and 你 in zh-Hans. A line must not sound like a nurse, a cheerleader, or a reproach.

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Nothing to take today. Enjoy it. | 今天没有要服用的，享受这一天吧。 | 今日は飲むものはありません。ゆっくり過ごしてくださいね。 | Hoy no tienes nada que tomar. Disfrútalo. | Heute musst du nichts einnehmen. Genieß den Tag. | 오늘은 복용할 게 없어요. 편안한 하루 보내세요. |
| Let’s add the first thing you take. | 来添加你服用的第一样东西吧。 | まずは、飲んでいるものを1つ追加しましょう。 | Añadamos lo primero que tomas. | Lass uns das Erste eintragen, das du nimmst. | 먼저 복용 중인 것을 하나 추가해 볼까요? |
| All done for today. Nice work. | 今天都完成了，做得好。 | 今日の分はすべて完了です。おつかれさまでした。 | Todo listo por hoy. Buen trabajo. | Für heute alles erledigt. Gut gemacht. | 오늘은 모두 마쳤어요. 잘하셨어요. |
| Your records will appear here, one day at a time. | 你的记录会一天天出现在这里。 | 記録は、一日ずつここにたまっていきます。 | Tus registros aparecerán aquí, día a día. | Deine Einträge erscheinen hier, Tag für Tag. | 기록은 하루하루 여기에 쌓여요. |
| Your data is safe. Nothing changed. | 你的数据很安全，没有任何改动。 | データは無事です。何も変更されていません。 | Tus datos están a salvo. No cambió nada. | Deine Daten sind sicher. Nichts wurde geändert. | 데이터는 안전해요. 바뀐 건 없어요. |
| Free some storage, then try again. Your data is safe. | 先腾出一些存储空间再试。你的数据很安全。 | 空き容量を確保してから、もう一度お試しください。データは無事です。 | Libera espacio y vuelve a intentarlo. Tus datos están a salvo. | Gib etwas Speicherplatz frei und versuche es erneut. Deine Daten sind sicher. | 저장 공간을 확보한 다음 다시 시도해 주세요. 데이터는 안전해요. |
| If your iPhone is locked, unlock it and try again. Your data is safe. | 如果 iPhone 锁着，先解锁再试。你的数据很安全。 | iPhoneがロックされている場合は、ロックを解除してもう一度お試しください。データは無事です。 | Si el iPhone está bloqueado, desbloquéalo y vuelve a intentarlo. Tus datos están a salvo. | Wenn dein iPhone gesperrt ist, entsperre es und versuche es erneut. Deine Daten sind sicher. | iPhone이 잠겨 있으면 잠금을 해제하고 다시 시도해 주세요. 데이터는 안전해요. |
| A newer version of Maru saved your data. It’s safe, and nothing changed. | 更新版本的 Maru 保存了你的数据。数据很安全，没有任何改动。 | より新しいバージョンのMaruがデータを保存しました。データは無事で、何も変更されていません。 | Una versión más reciente de Maru guardó tus datos. Están a salvo y no cambió nada. | Eine neuere Version von Maru hat deine Daten gespeichert. Sie sind sicher, und nichts wurde geändert. | 더 최신 버전의 Maru가 데이터를 저장했어요. 데이터는 안전하고, 바뀐 건 없어요. |
| This version of Maru can’t open your data. It’s safe, and nothing changed. | 这个版本的 Maru 打不开你的数据。数据很安全，没有任何改动。 | このバージョンのMaruはデータを開けません。データは無事で、何も変更されていません。 | Esta versión de Maru no puede abrir tus datos. Están a salvo y no cambió nada. | Diese Version von Maru kann deine Daten nicht öffnen. Sie sind sicher, und nichts wurde geändert. | 이 버전의 Maru는 데이터를 열 수 없어요. 데이터는 안전하고, 바뀐 건 없어요. |
| Your data file is damaged. Maru left it exactly as it was. | 你的数据文件坏了。Maru 没有动它，一切保持原样。 | データファイルが破損しています。Maruはファイルに一切手を加えていません。 | Tu archivo de datos está dañado. Maru lo dejó tal como estaba. | Deine Datendatei ist beschädigt. Maru hat sie genau so gelassen, wie sie war. | 데이터 파일이 손상되었어요. Maru는 파일을 그대로 두었어요. |
| This didn’t save. Please try again. | 这次没保存成功，请再试一次。 | うまく保存できませんでした。もう一度お試しください。 | No se guardó. Inténtalo de nuevo, por favor. | Das wurde nicht gespeichert. Bitte versuche es erneut. | 저장되지 않았어요. 다시 시도해 주세요. |
| This change didn’t save. Please try again. | 这次更改没保存成功，请再试一次。 | この変更はうまく保存できませんでした。もう一度お試しください。 | Este cambio no se guardó. Inténtalo de nuevo, por favor. | Diese Änderung wurde nicht gespeichert. Bitte versuche es erneut. | 이 변경 사항이 저장되지 않았어요. 다시 시도해 주세요. |
| Made with care by the Maru team. | Maru 团队用心制作。 | Maruチームが心を込めてつくりました。 | Hecho con cariño por el equipo de Maru. | Mit Sorgfalt gemacht vom Maru-Team. | Maru 팀이 정성을 담아 만들었어요. |

## Onboarding (D103, D104)

The eight strings below are new in `App/Localizable.xcstrings`: the three onboarding pages and their buttons. D104 removed the two tips and their strings. No native speaker read them. The reviewer checks the same three things as above, and that the voice is warm and calm (D101). "Stays on Your iPhone" also has an iPad form.

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Did I take it? Open Maru and you know. | 我吃了没？打开 Maru 就知道。 | 飲んだっけ？Maruを開けばすぐわかります。 | ¿Me lo tomé? Abre Maru y lo sabrás. | Schon genommen? Öffne Maru, und du weißt es. | 먹었던가? Maru를 열면 바로 알 수 있어요. |
| Maru reminds you on time, and one tap records each dose. | Maru 准时提醒你，点一下就能记下每次服用。 | Maruが時間どおりにお知らせ。タップひとつで毎回の服用を記録できます。 | Maru te avisa a tiempo, y con un toque registras cada dosis. | Maru erinnert dich pünktlich, und ein Tippen erfasst jede Dosis. | Maru가 제때 알려 드리고, 한 번 탭하면 복용이 기록돼요. |
| Stays on Your iPhone | 只留在你的 iPhone 上 | iPhoneの中だけに | Se queda en tu iPhone | Bleibt auf deinem iPhone | iPhone에만 남아요 |
| There’s no account to make and no ads. What you take is yours alone. | 不用注册账户，也没有广告。你服用的内容只属于你。 | アカウント登録も広告もありません。何を飲んでいるかは、あなただけのものです。 | No hay cuenta que crear ni anuncios. Lo que tomas es solo tuyo. | Kein Konto, keine Werbung. Was du nimmst, bleibt deine Sache. | 계정을 만들 필요도, 광고도 없어요. 무엇을 복용하는지는 나만 알아요. |
| Ready When You Are | 准备好了就开始吧 | 準備ができたら、はじめましょう | Empezamos cuando quieras | Los geht’s, wenn du so weit bist | 준비되면 시작해요 |
| Add a supplement or medication. You choose the time, and Maru reminds you. | 添加一种保健品或药物。时间由你来定，Maru 按时提醒你。 | サプリメントや薬を追加しましょう。時間はあなたが決めて、Maruがお知らせします。 | Añade un suplemento o un medicamento. Tú eliges la hora, y Maru te avisa. | Füge ein Supplement oder Medikament hinzu. Du wählst die Zeit, und Maru erinnert dich. | 영양제나 의약품을 추가해 보세요. 시간은 직접 정하고, 알림은 Maru가 드려요. |
| Continue | 继续 | 続ける | Continuar | Weiter | 계속 |
| Later | 以后再说 | あとで | Más tarde | Später | 나중에 |

## Appearance (D105)

The four strings below are new in `App/Localizable.xcstrings`: the menu "Appearance" in Settings and its three choices. No native speaker read them. The reviewer checks that each word matches the word of the iOS Settings page "Display & Brightness" in that language.

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Appearance | 外观 | 外観モード | Apariencia | Darstellung | 화면 모드 |
| System | 跟随系统 | システム | Sistema | System | 시스템 |
| Light | 浅色 | ライト | Claro | Hell | 라이트 |
| Dark | 深色 | ダーク | Oscuro | Dunkel | 다크 |

## Maru Pro (D107)

The strings below are new in `App/Localizable.xcstrings`: the paywall, the card of Today, and the section of Settings. "Maru Pro" stays in English in every language. No native speaker read them. The reviewer checks the same three things as above, that the voice is warm and calm with no pressure (D101), that "Family Sharing", "Apple Account", and "Settings" use the Apple words of that language, and that the price text "%@/year" reads well with a local price.

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Close | 关闭 | 閉じる | Cerrar | Schließen | 닫기 |
| Shareable with Family Sharing | 可通过“家人共享”共享 | ファミリー共有で共有できます | Se puede compartir con En familia | Mit der Familienfreigabe teilbar | 가족 공유로 함께 쓸 수 있어요 |
| A few extras for your routine. Everything you use now stays free. | 为你的日常多加几样贴心功能。你现在用的一切都继续免费。 | 毎日をもう少し便利にする追加機能です。今お使いの機能はすべて無料のままです。 | Unos extras para tu rutina. Todo lo que usas ahora sigue siendo gratis. | Ein paar Extras für deinen Alltag. Alles, was du jetzt nutzt, bleibt kostenlos. | 일상을 조금 더 편하게 해 줄 추가 기능이에요. 지금 쓰는 기능은 모두 계속 무료예요. |
| Next Dose on the Lock Screen | 锁定屏幕上的下次服用 | ロック画面に次の服用 | Próxima dosis en la pantalla bloqueada | Nächste Dosis auf dem Sperrbildschirm | 잠금 화면에 다음 복용 |
| See what’s next without opening Maru. | 不打开 Maru，也能看到下一次安排。 | Maruを開かなくても次の予定がわかります。 | Mira lo siguiente sin abrir Maru. | Sieh, was als Nächstes ansteht, ohne Maru zu öffnen. | Maru를 열지 않아도 다음 일정을 볼 수 있어요. |
| Apple Watch App | Apple Watch App | Apple Watchアプリ | App para Apple Watch | Apple Watch-App | Apple Watch 앱 |
| See and record today’s doses on your wrist. | 在手腕上查看并记录今天的服用。 | 今日の服用を手首で確認・記録できます。 | Ve y registra las dosis de hoy en tu muñeca. | Sieh und erfasse die Dosen von heute am Handgelenk. | 오늘의 복용을 손목에서 확인하고 기록해요. |
| Yearly | 按年 | 年額 | Anual | Jährlich | 연간 |
| per year | 每年 | 1年ごと | al año | pro Jahr | 1년마다 |
| %lld days free | 免费 %lld 天 | %lld日間無料 | %lld días gratis | %lld Tage kostenlos | %lld일 무료 |
| Lifetime | 永久 | 買い切り | De por vida | Dauerhaft | 평생 |
| one time | 一次性 | 1回のみ | un solo pago | einmalig | 한 번만 |
| No subscription | 不是订阅 | サブスクリプションなし | Sin suscripción | Kein Abo | 구독 없음 |
| Prices didn’t load. Check your connection and try again. | 价格没有加载出来。请检查网络后重试。 | 価格を読み込めませんでした。接続を確認して、もう一度お試しください。 | Los precios no se cargaron. Revisa tu conexión e inténtalo de nuevo. | Die Preise wurden nicht geladen. Prüfe deine Verbindung und versuche es erneut. | 가격을 불러오지 못했어요. 연결을 확인한 뒤 다시 시도해 주세요. |
| Subscribe Yearly | 按年订阅 | 年額で登録 | Suscripción anual | Jährlich abonnieren | 연간 구독 |
| Buy Lifetime | 永久买断 | 買い切りで購入 | Comprar de por vida | Dauerhaft kaufen | 평생 이용권 구매 |
| Continue Free | 继续免费使用 | 無料で続ける | Seguir gratis | Kostenlos weiter | 무료로 계속하기 |
| The yearly plan renews each year until you cancel it in Settings. Cancel at least 24 hours before it renews. | 按年方案会每年自动续订，直到你在“设置”中取消。请在续订前至少 24 小时取消。 | 年額プランは、設定でキャンセルするまで毎年自動更新されます。更新の24時間前までにキャンセルしてください。 | El plan anual se renueva cada año hasta que lo canceles en Ajustes. Cancela al menos 24 horas antes de la renovación. | Der Jahresplan verlängert sich jedes Jahr, bis du ihn in den Einstellungen kündigst. Kündige mindestens 24 Stunden vor der Verlängerung. | 연간 플랜은 설정에서 취소할 때까지 매년 갱신돼요. 갱신 24시간 전까지 취소해 주세요. |
| Restore Purchases | 恢复购买 | 購入を復元 | Restaurar compras | Käufe wiederherstellen | 구입 복원 |
| Redeem Code | 兑换代码 | コードを使う | Canjear código | Code einlösen | 코드 사용 |
| Terms of Use | 使用条款 | 利用規約 | Términos de uso | Nutzungsbedingungen | 이용 약관 |
| Your purchase is waiting for approval. Pro turns on when it’s approved. | 你的购买正在等待批准。批准后 Pro 就会开启。 | 購入は承認待ちです。承認されるとProが有効になります。 | Tu compra está pendiente de aprobación. Pro se activará cuando se apruebe. | Dein Kauf wartet auf Freigabe. Pro wird aktiv, sobald er freigegeben ist. | 구입이 승인을 기다리고 있어요. 승인되면 Pro가 켜져요. |
| The purchase didn’t go through. Please try again. | 购买没有完成。请再试一次。 | 購入を完了できませんでした。もう一度お試しください。 | La compra no se completó. Inténtalo de nuevo. | Der Kauf hat nicht geklappt. Bitte versuche es erneut. | 구입이 완료되지 않았어요. 다시 시도해 주세요. |
| Maru Pro is back. Thank you. | Maru Pro 已恢复。谢谢你。 | Maru Proを復元しました。ありがとうございます。 | Maru Pro ha vuelto. Gracias. | Maru Pro ist wieder da. Danke. | Maru Pro가 복원됐어요. 고마워요. |
| No Maru Pro purchase was found for this Apple Account. | 这个 Apple 账户没有 Maru Pro 的购买记录。 | このApple AccountにMaru Proの購入は見つかりませんでした。 | No se encontró ninguna compra de Maru Pro en esta cuenta de Apple. | Für diesen Apple Account wurde kein Kauf von Maru Pro gefunden. | 이 Apple 계정에서 Maru Pro 구입을 찾지 못했어요. |
| Free for %lld days | 免费使用 %lld 天 | %lld日間無料 | Gratis durante %lld días | %lld Tage kostenlos | %lld일 동안 무료 |
| Day %lld | 第 %lld 天 | %lld日目 | Día %lld | Tag %lld | %lld일째 |
| %@/year. Cancel any time in Settings. | %@/年。随时可在“设置”中取消。 | %@/年。設定でいつでもキャンセルできます。 | %@ al año. Cancela cuando quieras en Ajustes. | %@ pro Jahr. Jederzeit in den Einstellungen kündbar. | 연 %@. 설정에서 언제든 취소할 수 있어요. |
| Preview of your Lock Screen | 锁定屏幕预览 | ロック画面のプレビュー | Vista previa de tu pantalla bloqueada | Vorschau deines Sperrbildschirms | 잠금 화면 미리 보기 |
| See your next dose on the Lock Screen | 在锁定屏幕上看到下次服用 | 次の服用をロック画面で確認 | Ve tu próxima dosis en la pantalla bloqueada | Deine nächste Dosis auf dem Sperrbildschirm | 다음 복용을 잠금 화면에서 확인하세요 |
| See Maru Pro | 了解 Maru Pro | Maru Proを見る | Ver Maru Pro | Maru Pro ansehen | Maru Pro 보기 |
| Hide | 隐藏 | 非表示 | Ocultar | Ausblenden | 숨기기 |
| Active, Yearly | 已开启，按年 | 有効（年額） | Activo, anual | Aktiv, jährlich | 사용 중, 연간 |
| Active, Lifetime | 已开启，永久 | 有効（買い切り） | Activo, de por vida | Aktiv, dauerhaft | 사용 중, 평생 |
| Manage Subscription | 管理订阅 | サブスクリプションを管理 | Gestionar suscripción | Abo verwalten | 구독 관리 |
| The restore didn’t go through. Please try again. | 恢复没有完成。请再试一次。 | 復元を完了できませんでした。もう一度お試しください。 | La restauración no se completó. Inténtalo de nuevo. | Die Wiederherstellung hat nicht geklappt. Bitte versuche es erneut. | 복원이 완료되지 않았어요. 다시 시도해 주세요. |
| Reminders, records, and your data stay free. | 提醒、记录和你的数据都继续免费。 | リマインダー、記録、データはずっと無料です。 | Los recordatorios, los registros y tus datos siguen siendo gratis. | Erinnerungen, Einträge und deine Daten bleiben kostenlos. | 미리 알림, 기록, 내 데이터는 계속 무료예요. |

## App icons and reminder sounds (D112)

The strings below are new in `App/Localizable.xcstrings`: the rows "App Icon" and "Reminder Sound" in Settings, their pages, and the names of the icons and the sounds. D120 replaced the six sound names with eight new names (the last eight rows of the table). "Blue", "Purple", "Green", and "Not Changed" use the existing translations. No native speaker read them. The reviewer checks that each sound name is a short, calm word, that "Default" matches the word of the iOS Sounds settings in that language, and that the voice is warm and calm with no pressure (D101).

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| App Icon | App 图标 | Appのアイコン | Icono de la app | App-Symbol | 앱 아이콘 |
| Default | 默认 | デフォルト | Predeterminado | Standard | 기본 |
| Night | 夜色 | ナイト | Noche | Nacht | 나이트 |
| Mono | 单色 | モノクロ | Mono | Mono | 모노 |
| The icon didn’t change. Please try again. | 图标没有更改，请再试一次。 | アイコンは変更されませんでした。もう一度お試しください。 | El icono no cambió. Inténtalo de nuevo, por favor. | Das Symbol wurde nicht geändert. Bitte versuche es erneut. | 아이콘이 바뀌지 않았어요. 다시 시도해 주세요. |
| Look at every icon for free. Maru Pro lets you choose one. | 每个图标都可以免费查看，用 Maru Pro 就能选用。 | どのアイコンも無料で見られます。Maru Proで選べます。 | Puedes ver todos los iconos gratis. Con Maru Pro puedes elegir uno. | Du kannst dir jedes Symbol kostenlos ansehen. Mit Maru Pro kannst du eines wählen. | 모든 아이콘을 무료로 볼 수 있어요. Maru Pro로 하나를 고를 수 있어요. |
| Reminder Sound | 提醒声音 | リマインダーの音 | Sonido de recordatorio | Erinnerungston | 미리 알림 소리 |
| Listen to each sound for free. Maru Pro lets you choose one. | 每个声音都可以免费试听，用 Maru Pro 就能选用。 | どの音も無料で試聴できます。Maru Proで選べます。 | Puedes escuchar todos los sonidos gratis. Con Maru Pro puedes elegir uno. | Du kannst dir jeden Ton kostenlos anhören. Mit Maru Pro kannst du einen wählen. | 모든 소리를 무료로 들어 볼 수 있어요. Maru Pro로 하나를 고를 수 있어요. |
| Play %@ | 播放“%@” | 「%@」を再生 | Reproducir %@ | %@ abspielen | %@ 재생 |
| Rising Chime | 上升风铃 | 上昇するチャイム | Campanillas | Aufsteigendes Glockenspiel | 상승하는 차임 |
| Marimba | 马林巴 | マリンバ | Marimba | Marimba | 마림바 |
| Soft Bell | 柔和钟声 | やわらかなベル | Campana suave | Sanfte Glocke | 부드러운 종소리 |
| Glass | 玻璃 | グラス | Cristal | Glas | 유리 |
| Chime Bars | 音条风铃 | チャイムバー | Barras de campanas | Klangstäbe | 차임 바 |
| Hand Bell | 手摇铃 | ハンドベル | Campanilla | Handglocke | 핸드벨 |
| Music Box | 八音盒 | オルゴール | Caja de música | Spieluhr | 오르골 |
| Synth Bell | 合成铃声 | シンセベル | Campana sintética | Synthie-Glocke | 신스 벨 |

## App color of Maru Pro (D114)

The strings below are new or changed. They are drafts. No native speaker read them. The reviewer checks that the voice is warm and calm with no pressure (D101), and that "App Color", "App Icon", and "Reminder Sound" use the same words as their rows in Settings.

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Make It Yours | 随心定制 | 自分らしく | A tu manera | Ganz nach deinem Geschmack | 나만의 스타일로 |
| App colors, icons, and reminder sounds. | App 颜色、图标和提醒声音。 | Appのカラー、アイコン、リマインダーの音。 | Colores e iconos de la app, y sonidos de recordatorio. | App-Farben, App-Symbole und Erinnerungstöne. | 앱 색상, 아이콘, 미리 알림 소리. |
| Maru Pro adds this, an Apple Watch app, and more colors, icons, and sounds. Everything else stays free. | Maru Pro 提供这项功能，还有 Apple Watch App 和更多颜色、图标与提醒音。其他一切都继续免费。 | Maru Proでは、この機能のほか、Apple Watchアプリや追加のカラー、アイコン、サウンドが使えます。それ以外はすべて無料のままです。 | Maru Pro añade esto, una app para Apple Watch y más colores, iconos y sonidos. Todo lo demás sigue siendo gratis. | Maru Pro bietet das, eine Apple Watch-App und mehr Farben, Symbole und Töne. Alles andere bleibt kostenlos. | Maru Pro에는 이 기능과 Apple Watch 앱, 더 많은 색상과 아이콘, 소리가 있어요. 나머지는 모두 계속 무료예요. |
| This is a preview. With Maru Pro, the whole app uses this color. | 这是预览。有了 Maru Pro，整个 App 都会用这个颜色。 | これはプレビューです。Maru Proなら、App全体がこのカラーになります。 | Es una vista previa. Con Maru Pro, toda la app usa este color. | Das ist eine Vorschau. Mit Maru Pro nutzt die ganze App diese Farbe. | 미리 보기예요. Maru Pro가 있으면 앱 전체에 이 색상이 적용돼요. |

## Watch app of Maru Pro (D111)

The strings below are new. They are drafts. No native speaker read them. The reviewer checks them in `Watch/Localizable.xcstrings`. They show on the locked screen of the Watch app for a free user.

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Maru Pro | Maru Pro | Maru Pro | Maru Pro | Maru Pro | Maru Pro |
| See and record today’s doses on your wrist. | 在手腕上查看并记录今天的服用。 | 今日の服用を手首で確認・記録できます。 | Ve y registra las dosis de hoy en tu muñeca. | Sieh und erfasse die Dosen von heute am Handgelenk. | 오늘의 복용을 손목에서 확인하고 기록해요. |
| Unlock with Maru Pro on your iPhone. | 在 iPhone 上开通 Maru Pro 即可使用。 | iPhoneのMaru Proで使えるようになります。 | Desbloquéala con Maru Pro en tu iPhone. | Schalte sie mit Maru Pro auf deinem iPhone frei. | iPhone에서 Maru Pro로 잠금 해제하세요. |
| Open on iPhone | 在 iPhone 上打开 | iPhoneで開く | Abrir en el iPhone | Auf dem iPhone öffnen | iPhone에서 열기 |
| Sent. Open Maru on your iPhone to see Maru Pro. | 已发送。在 iPhone 上打开 Maru 就能看到 Maru Pro。 | 送信しました。iPhoneでMaruを開くとMaru Proが表示されます。 | Enviado. Abre Maru en tu iPhone para ver Maru Pro. | Gesendet. Öffne Maru auf deinem iPhone, um Maru Pro zu sehen. | 보냈어요. iPhone에서 Maru를 열면 Maru Pro를 볼 수 있어요. |
| Your iPhone is not reachable. Open Maru on your iPhone to see Maru Pro. | 连不上 iPhone。在 iPhone 上打开 Maru 来查看 Maru Pro。 | iPhoneに接続できません。iPhoneでMaruを開いてMaru Proをご覧ください。 | No se puede conectar con tu iPhone. Abre Maru en tu iPhone para ver Maru Pro. | Dein iPhone ist nicht erreichbar. Öffne Maru auf deinem iPhone, um Maru Pro zu sehen. | iPhone에 연결할 수 없어요. iPhone에서 Maru를 열어 Maru Pro를 확인해 주세요. |

## Last Dose widget and Siri (D108)

The strings below are new. They are drafts. No native speaker read them. The reviewer checks the same three things as above, and that the voice is warm and calm (D101).

Siri phrases, in `App/AppShortcuts.xcstrings`. A phrase must sound like a natural spoken request. `${applicationName}` is "Maru", and `${item}` is an item name. The reviewer says each phrase to Siri on a device.

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Check my last dose in ${applicationName} | ${applicationName}里查看上一次服用 | ${applicationName}で前回の服用を確認 | Consulta mi última dosis en ${applicationName} | Zeig meine letzte Dosis in ${applicationName} | ${applicationName}에서 마지막 복용 확인 |
| Did I take my ${item} in ${applicationName} | ${applicationName}里我吃${item}了吗 | ${applicationName}で${item}を飲んだ | Tomé ${item} en ${applicationName} | Habe ich ${item} in ${applicationName} genommen | ${applicationName}에서 ${item} 먹었어 |
| Last dose of ${item} in ${applicationName} | ${applicationName}里${item}的上一次服用 | ${applicationName}で${item}の前回の服用 | Última dosis de ${item} en ${applicationName} | Letzte Dosis von ${item} in ${applicationName} | ${applicationName}에서 ${item} 마지막 복용 |
| Log my doses in ${applicationName} | 用${applicationName}记下服用 | ${applicationName}で今の分を記録 | Anota mis dosis en ${applicationName} | Trag meine Dosen in ${applicationName} ein | ${applicationName}에 복용 남겨 줘 |
| Next dose in ${applicationName} | ${applicationName}下次服用 | ${applicationName}で次の服用 | Próxima dosis en ${applicationName} | Nächste Dosis in ${applicationName} | ${applicationName}에서 다음 복용 |
| Record my doses in ${applicationName} | 在${applicationName}里记录服用 | ${applicationName}で服用を記録 | Registra mis dosis en ${applicationName} | Erfasse meine Dosen in ${applicationName} | ${applicationName}에서 복용 기록해 줘 |
| What do I take next in ${applicationName} | ${applicationName}里下一次吃什么 | ${applicationName}で次に飲むものは | Qué tomo ahora en ${applicationName} | Was nehme ich als Nächstes in ${applicationName} | ${applicationName}에서 다음에 뭐 먹어 |
| What's next in ${applicationName} | ${applicationName}接下来是什么 | ${applicationName}で次は何 | Qué sigue en ${applicationName} | Was steht als Nächstes an in ${applicationName} | ${applicationName}에서 다음은 뭐야 |
| When did I last take ${item} in ${applicationName} | ${applicationName}里我上次什么时候吃的${item} | ${applicationName}で${item}を最後に飲んだのはいつ | Cuándo tomé ${item} por última vez en ${applicationName} | Wann habe ich zuletzt ${item} in ${applicationName} genommen | ${applicationName}에서 ${item} 마지막으로 언제 먹었어 |

Siri answers and Shortcuts titles, in `App/Localizable.xcstrings`. The text that names the iPhone also has an iPad form. With "Show Names in Reminders" off, "%lld doses" takes the place of the names in "Next up", "Record as taken now", and "Recorded as taken".

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Next up: %@, planned for %@. | 接下来：%1$@，计划时间 %2$@。 | 次は%1$@です。予定は%2$@です。 | Lo siguiente: %1$@, hora prevista %2$@. | Als Nächstes: %1$@, geplant um %2$@. | 다음 차례: %1$@, 예정 시간 %2$@. |
| Maru has no taken record for %@ yet. | Maru 里还没有%@的服用记录。 | Maruには%@の服用記録がまだありません。 | Maru aún no tiene ningún registro de toma de %@. | Für %@ gibt es in Maru noch keine Aufzeichnung einer Einnahme. | Maru에 아직 %@ 복용 기록이 없어요. |
| Your last record for %@: taken today at %@. | %1$@的上一次记录：今天 %2$@ 已服用。 | %1$@の最新の記録：今日%2$@に服用済み。 | Tu último registro de %1$@: tomado hoy a las %2$@. | Deine letzte Aufzeichnung für %1$@: heute um %2$@ eingenommen. | %1$@ 마지막 기록: 오늘 %2$@ 복용함. |
| Your last record for %@: taken yesterday at %@. | %1$@的上一次记录：昨天 %2$@ 已服用。 | %1$@の最新の記録：昨日%2$@に服用済み。 | Tu último registro de %1$@: tomado ayer a las %2$@. | Deine letzte Aufzeichnung für %1$@: gestern um %2$@ eingenommen. | %1$@ 마지막 기록: 어제 %2$@ 복용함. |
| Your last record for %@: taken on %@ at %@. | %1$@的上一次记录：%2$@ %3$@ 已服用。 | %1$@の最新の記録：%2$@ %3$@に服用済み。 | Tu último registro de %1$@: tomado el %2$@ a las %3$@. | Deine letzte Aufzeichnung für %1$@: am %2$@ um %3$@ eingenommen. | %1$@ 마지막 기록: %2$@ %3$@ 복용함. |
| Nothing is due right now. You’re all set. | 现在没有需要记录的，一切都好。 | 今は記録するものはありません。大丈夫ですよ。 | Ahora no hay nada pendiente. Todo en orden. | Gerade steht nichts an. Alles in Ordnung. | 지금은 기록할 게 없어요. 다 괜찮아요. |
| Record as taken now: %@? | 现在将%@记录为已服用？ | %@を今の時刻で服用済みとして記録しますか？ | ¿Registrar ahora como tomado: %@? | Jetzt als eingenommen erfassen: %@? | %@을(를) 지금 복용함으로 기록할까요? |
| Recorded as taken: %@. | 已记录为已服用：%@。 | 服用済みとして記録しました：%@。 | Registrado como tomado: %@. | Als eingenommen erfasst: %@. | 복용함으로 기록했어요: %@. |
| %lld doses (one: %lld dose) | %lld 项 | %lld件 | %lld dosis | %lld Dosen (one: %lld Dosis) | %lld개 항목 |
| Maru has no taken record for this item yet. | Maru 里还没有这个药品的服用记录。 | Maruにはこの項目の服用記録がまだありません。 | Maru aún no tiene ningún registro de toma de este elemento. | Für diesen Eintrag gibt es in Maru noch keine Aufzeichnung einer Einnahme. | Maru에 아직 이 항목의 복용 기록이 없어요. |
| Your last record: taken today at %@. | 上一次记录：今天 %@ 已服用。 | 最新の記録：今日%@に服用済み。 | Tu último registro: tomado hoy a las %@. | Deine letzte Aufzeichnung: heute um %@ eingenommen. | 마지막 기록: 오늘 %@ 복용함. |
| Your last record: taken yesterday at %@. | 上一次记录：昨天 %@ 已服用。 | 最新の記録：昨日%@に服用済み。 | Tu último registro: tomado ayer a las %@. | Deine letzte Aufzeichnung: gestern um %@ eingenommen. | 마지막 기록: 어제 %@ 복용함. |
| Your last record: taken on %@ at %@. | 上一次记录：%1$@ %2$@ 已服用。 | 最新の記録：%1$@ %2$@に服用済み。 | Tu último registro: tomado el %1$@ a las %2$@. | Deine letzte Aufzeichnung: am %1$@ um %2$@ eingenommen. | 마지막 기록: %1$@ %2$@ 복용함. |
| Maru can’t open your records right now. If your iPhone restarted, unlock it first, then ask again. | Maru 现在打不开你的记录。如果你的 iPhone 刚重启过，请先解锁，再问一次。 | Maruは今、記録を開けません。iPhoneを再起動した場合は、先にロックを解除してからもう一度お試しください。 | Maru no puede abrir tus registros ahora. Si el iPhone se reinició, desbloquéalo primero y vuelve a preguntar. | Maru kann deine Aufzeichnungen gerade nicht öffnen. Wenn dein iPhone neu gestartet wurde, entsperre es zuerst und frag dann erneut. | Maru가 지금 기록을 열 수 없어요. iPhone을 다시 시작했다면 먼저 잠금을 해제한 후 다시 물어봐 주세요. |
| Maru couldn’t confirm the save. Open Maru to check your records. | Maru 没能确认是否已保存。请打开 Maru 查看你的记录。 | Maruは保存を確認できませんでした。Maruを開いて記録を確認してください。 | Maru no pudo confirmar que se guardó. Abre Maru para revisar tus registros. | Maru konnte das Speichern nicht bestätigen. Öffne Maru, um deine Aufzeichnungen zu prüfen. | Maru가 저장을 확인하지 못했어요. Maru를 열어 기록을 확인해 주세요. |
| Which item? | 哪个药品？ | どの項目ですか？ | ¿Qué elemento? | Welcher Eintrag? | 어떤 항목인가요? |
| Item | 药品 | 項目 | Elemento | Eintrag | 항목 |
| Last dose of ${item} | ${item}的上一次服用 | ${item}の前回の服用 | Última dosis de ${item} | Letzte Dosis von ${item} | ${item} 마지막 복용 |
| Last Dose of an Item | 某个药品的上一次服用 | 項目の前回の服用 | Última dosis de un elemento | Letzte Dosis eines Eintrags | 항목의 마지막 복용 |
| Record Due Doses | 记录当前的服用 | 今の分を記録 | Registrar dosis pendientes | Fällige Dosen erfassen | 지금 복용분 기록 |
| Last Dose | 上一次服用 | 前回の服用 | Última dosis | Letzte Dosis | 마지막 복용 |
| Record Doses | 记录服用 | 服用を記録 | Registrar dosis | Dosen erfassen | 복용 기록 |

The "Last Dose" widget, in `Widget/Localizable.xcstrings`.

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Last Dose | 上一次服用 | 前回の服用 | Última dosis | Letzte Dosis | 마지막 복용 |
| See your newest taken dose and its time. | 查看最近一次服用及其时间。 | 最新の服用とその時刻を表示します。 | Mira tu dosis tomada más reciente y su hora. | Zeigt deine letzte eingenommene Dosis und ihre Uhrzeit. | 가장 최근 복용과 그 시간을 보여줘요. |
| %@, %@ | %1$@，%2$@ | %1$@、%2$@ | %1$@, %2$@ | %1$@, %2$@ | %1$@, %2$@ |
| No records yet | 还没有记录 | まだ記録はありません | Aún no hay registros | Noch keine Aufzeichnungen | 아직 기록이 없어요 |
| Your last dose will show here. | 你最近一次服用会显示在这里。 | 最新の服用がここに表示されます。 | Tu última dosis aparecerá aquí. | Deine letzte Dosis erscheint hier. | 가장 최근 복용이 여기에 표시돼요. |
| Yesterday, %@ | 昨天 %@ | 昨日 %@ | Ayer, %@ | Gestern, %@ | 어제 %@ |
| Dose recorded | 已记录服用 | 服用を記録済み | Dosis registrada | Dosis erfasst | 복용 기록됨 |

## Live Activity (D110)

The strings below are new. They are drafts. No native speaker read them. Check that the Settings text uses the system name of Live Activities in each language.

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Next Dose on Lock Screen | 在锁定屏幕显示下次服用 | ロック画面に次の服用を表示 | Próxima dosis en la pantalla bloqueada | Nächste Dosis auf dem Sperrbildschirm | 잠금 화면에 다음 복용 표시 |
| Shows your next dose, its time, and a button to record it. | 显示下次服用、服用时间和一个记录按钮。 | 次の服用とその時刻、記録するボタンを表示します。 | Muestra tu próxima dosis, su hora y un botón para registrarla. | Zeigt deine nächste Dosis, ihre Uhrzeit und eine Taste zum Erfassen. | 다음 복용과 그 시간, 기록 버튼을 보여 줘요. |
| Live Activities are off for Maru. Turn them on in the Settings app, under Maru. | Maru 的实时活动已关闭。请在“设置”App 的 Maru 中打开。 | Maruのライブアクティビティがオフになっています。設定アプリの「Maru」でオンにしてください。 | Las actividades en vivo están desactivadas para Maru. Actívalas en la app Ajustes, en Maru. | Live-Aktivitäten sind für Maru deaktiviert. Aktiviere sie in der App „Einstellungen“ unter „Maru“. | Maru의 실시간 현황이 꺼져 있어요. 설정 앱의 Maru에서 켜 주세요. |
| Couldn’t confirm the save. Open Maru to check. | 没能确认是否已保存。请打开 Maru 查看。 | 保存を確認できませんでした。Maruを開いて確認してください。 | No se pudo confirmar que se guardó. Abre Maru para revisarlo. | Speichern nicht bestätigt. Öffne Maru zum Prüfen. | 저장을 확인하지 못했어요. Maru를 열어 확인해 주세요. |
| Records these doses as taken | 把这些服用记为已服用 | これらの服用を服用済みとして記録します | Registra estas dosis como tomadas | Erfasst diese Dosen als eingenommen | 이 복용들을 복용함으로 기록해요 |
| %lld more (the end of the list "Vitamin D, Iron, Zinc, and 2 more") | 另外 %lld 项 | ほか%lld件 | %lld más | %lld weitere | 그 외 %lld개 |

The button "Taken", "%lld doses", and "Open Maru to update." reuse the text of the widgets and of Siri. The relative time ("in 12 minutes", "12 minutes ago") comes from the system in each language. The text "Not recorded yet" was removed on 2026-10-28.

## Next Dose widget (D113)

The strings below are new, in `Widget/Localizable.xcstrings`. They are drafts. No native speaker read them. The reviewer checks that the voice is warm and calm (D101), and that "In %@" reads well with the relative time of the system, for example "2 hr, 5 min". "%lld doses" and "%lld more" have the text of the Live Activity (D110).

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Next Dose | 下一次服用 | 次の服用 | Próxima dosis | Nächste Dosis | 다음 복용 |
| See your next dose and the time left. | 查看下一次服用和剩余时间。 | 次の服用と残り時間を表示します。 | Mira tu próxima dosis y el tiempo que falta. | Zeigt deine nächste Dosis und die verbleibende Zeit. | 다음 복용과 남은 시간을 보여줘요. |
| In %@ | %@后 | あと%@ | En %@ | In %@ | %@ 후 |
| All done for today | 今天都完成了 | 今日の分はすべて完了 | Todo listo por hoy | Für heute alles erledigt | 오늘은 모두 마쳤어요 |
| Not recorded yet | 还没记录 | まだ記録していません | Aún sin registrar | Noch nicht erfasst | 아직 기록 안 함 |

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

## Maru Pro look (D115)

Seven new strings, and three from the first D115 round. No native speaker read them. The reviewer checks that the labels have at most four words or the same length as English, that the terms lines keep the order "days, price" (the number of days first, then the price), and that each line fits at a large text size. "Apple Watch" stays in English in every language. Each terms line states the price, the period, and that the plan renews until the user cancels, as App Review 3.1.2 needs.

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Try It Free | 免费试用 | 無料で試す | Probar gratis | Gratis testen | 무료로 시작하기 |
| Free for %lld days, then %@ per year. Renews until you cancel. | 免费 %1$lld 天，之后每年 %2$@。取消前会自动续订。 | %1$lld日間無料、その後は年額%2$@。キャンセルするまで自動更新されます。 | Gratis durante %1$lld días, luego %2$@ al año. Se renueva hasta que lo canceles. | %1$lld Tage kostenlos, dann %2$@ pro Jahr. Verlängert sich, bis du kündigst. | %1$lld일 무료, 이후 연 %2$@. 취소할 때까지 갱신돼요. |
| %@ per year. Renews until you cancel. | 每年 %@。取消前会自动续订。 | 年額%@。キャンセルするまで自動更新されます。 | %@ al año. Se renueva hasta que lo canceles. | %@ pro Jahr. Verlängert sich, bis du kündigst. | 연 %@. 취소할 때까지 갱신돼요. |
| One payment. It does not renew. | 一次付款，不会续订。 | 1回のお支払いです。更新はありません。 | Un solo pago. No se renueva. | Einmalige Zahlung. Keine Verlängerung. | 한 번만 결제해요. 갱신되지 않아요. |
| Welcome to Maru Pro | 欢迎使用 Maru Pro | Maru Proへようこそ | Te damos la bienvenida a Maru Pro | Willkommen bei Maru Pro | Maru Pro에 오신 것을 환영해요 |
| Thank you. Your extras are ready. | 谢谢你。新增功能已就绪。 | ありがとうございます。追加機能をお使いいただけます。 | Gracias. Tus extras ya están listos. | Danke. Deine Extras sind bereit. | 고마워요. 추가 기능을 지금 쓸 수 있어요. |
| Lock Screen, Apple Watch, and more | 锁定屏幕、Apple Watch 等 | ロック画面、Apple Watchなど | Pantalla bloqueada, Apple Watch y más | Sperrbildschirm, Apple Watch und mehr | 잠금 화면, Apple Watch 등 |

## Paywall style B (D116)

D117 redesigned the lower half and added no string. The strings below and the ones of D115 are all that the two looks show.

Five new strings for the second paywall. No native speaker read them. The reviewer checks that the headline and the supporting line fit two to four lines at a large text size, that the terms lines keep the order "days, price", and that each terms line states the price, the period, that the plan renews, and that the user can cancel (App Review 3.1.2). The headline names the result "a glance at the next dose", and the supporting line says that the reminders stay free.

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Your next dose, at a glance. | 下一次服药，一目了然。 | 次の服用が、ひと目でわかる。 | Tu próxima dosis, de un vistazo. | Deine nächste Dosis auf einen Blick. | 다음 복용을 한눈에. |
| Add Lock Screen, Apple Watch, and your own look. Reminders stay free. | 添加锁定屏幕、Apple Watch 和专属外观。提醒仍然免费。 | ロック画面、Apple Watch、あなた好みの見た目を追加。リマインダーは引き続き無料です。 | Añade pantalla bloqueada, Apple Watch y tu propio estilo. Los recordatorios siguen siendo gratis. | Mit Sperrbildschirm, Apple Watch und eigenem Look. Erinnerungen bleiben kostenlos. | 잠금 화면, Apple Watch, 나만의 스타일을 더해요. 알림은 계속 무료예요. |
| Free for %lld days, then %@ per year. Renews automatically. Cancel anytime. | 免费 %1$lld 天，之后每年 %2$@。自动续订，可随时取消。 | %1$lld日間無料、その後は年額%2$@。自動更新で、いつでもキャンセルできます。 | Gratis durante %1$lld días, luego %2$@ al año. Se renueva automáticamente. Cancela cuando quieras. | %1$lld Tage kostenlos, dann %2$@ pro Jahr. Verlängert sich automatisch. Jederzeit kündbar. | %1$lld일 무료, 이후 연 %2$@. 자동으로 갱신되며 언제든 취소할 수 있어요. |
| %@ per year. Renews automatically. Cancel anytime. | 每年 %@。自动续订，可随时取消。 | 年額%@。自動更新で、いつでもキャンセルできます。 | %@ al año. Se renueva automáticamente. Cancela cuando quieras. | %@ pro Jahr. Verlängert sich automatisch. Jederzeit kündbar. | 연 %@. 자동으로 갱신되며 언제든 취소할 수 있어요. |
| Start Free Trial | 开始免费试用 | 無料トライアルを開始 | Empezar prueba gratis | Gratis testen starten | 무료 체험 시작 |

## Final paywall (D118, changed by D119)

Eight new strings. "Try It Free", "Continue Free", "No subscription", "per year", "one time", the supporting line of D116, and the two terms lines of D116 left the catalog. The terms lines of D115 are in use again. No native speaker read them. The reviewer checks that each benefit line fits one or two lines at a large text size, that "Cancel anytime" and "One payment" are true short claims in the language, and that the note about the independent developer sounds warm and plain.

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Pick your app color, icon, and reminder sound. | 选择应用颜色、图标和提醒声音。 | アプリのカラー、アイコン、通知音を選べます。 | Elige el color, el icono y el sonido de los recordatorios. | Wähle App-Farbe, Symbol und Erinnerungston. | 앱 색상, 아이콘, 알림 소리를 골라요. |
| One time | 一次买断 | 1回のみ | Pago único | Einmalig | 한 번만 |
| Cancel anytime | 可随时取消 | いつでもキャンセル可能 | Cancela cuando quieras | Jederzeit kündbar | 언제든 취소 가능 |
| One payment | 一次付款 | 1回のお支払い | Un solo pago | Einmalige Zahlung | 한 번만 결제 |
| Share with your family | 与家人共享 | ご家族と共有 | Compártelo con tu familia | Mit der Familie teilen | 가족과 공유 |
| Maru is made by one independent developer. Thank you for your support. | Maru 由一位独立开发者制作。感谢你的支持。 | Maruは一人の個人開発者が作っています。応援ありがとうございます。 | Maru la crea un solo desarrollador independiente. Gracias por tu apoyo. | Maru wird von einem einzelnen unabhängigen Entwickler gemacht. Danke für deine Unterstützung. | Maru는 한 명의 독립 개발자가 만들어요. 응원해 주셔서 고마워요. |

## Paywall, third round (D119)

Four strings changed, and four left the catalog: "Maru is made by one independent developer. Thank you for your support.", "Share with your family", "Cancel anytime", and "One payment". The three terms lines changed to end with "Cancel anytime." or "Yours to keep.", and the third benefit line is shorter. The German first benefit line is shorter too. No native speaker read them. The reviewer checks that each line fits one line on an iPhone 17e (checked in en, zh-Hans, de, and es, not in ja and ko), and that each terms line states the price, the period, and the cancel right (App Review 3.1.2).

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Free for %lld days, then %@ per year. Cancel anytime. | 免费 %1$lld 天，之后每年 %2$@。可随时取消。 | %1$lld日間無料、その後は年額%2$@。いつでもキャンセル可能。 | %1$lld días gratis, luego %2$@ al año. Cancela cuando quieras. | %1$lld Tage gratis, dann %2$@ pro Jahr. Jederzeit kündbar. | %1$lld일 무료, 이후 연 %2$@. 언제든 취소 가능. |
| %@ per year. Cancel anytime. | 每年 %@。可随时取消。 | 年額%@。いつでもキャンセル可能。 | %@ al año. Cancela cuando quieras. | %@ pro Jahr. Jederzeit kündbar. | 연 %@. 언제든 취소 가능. |

## Paywall plan tiles (D119, fourth round)

Two strings left the catalog ("One time" and "One payment. Yours to keep."). Two strings are new. The lifetime plan has no terms line any more, because its tile says "Pay once. It’s yours." (seventh round of D119). "%lld days free" is now the tag on the top edge of the yearly tile. No native speaker read them. The reviewer checks that each line fits one line in a tile of about 137 points (checked on an iPhone 17e in all six languages), that "Pay once. It’s yours." is a true short claim, and that the monthly line reads as the yearly price divided by 12.

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Pay once. It’s yours. | 买一次，永久归你 | 1回払いで、あなたのもの | Un pago. Es tuyo. | Einmal zahlen. Deins. | 한 번 결제로 내 것 |
| ≈ %@/month | 约 %@/月 | 月あたり約%@ | ≈ %@/mes | ≈ %@/Monat | 월 약 %@ |

## Paywall benefit copy (D119, sixth round)

Six strings replace six strings: "Dose on Lock Screen", "See your next dose without opening Maru.", "Apple Watch", "Record a dose from your wrist.", "Colors, Icons, Sounds", and "Choose your app color, icon, and sound." left the catalog. The English text went through two Codex reviews with five simulated personas (`~/Documents/Research/maru/paywall-redesign/copy-review/`). The translations are natural, not literal. No native speaker read them. The reviewer checks that each line fits one line on an iPhone 17e (checked in all six languages) and that the iPhone need in the second row reads as a plain fact. "Taken" in the second row uses the translation of the button "Taken".

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Right on your Lock Screen | 就在锁定屏幕上 | ロック画面にそのまま表示 | En tu pantalla bloqueada | Direkt auf dem Sperrbildschirm | 잠금 화면에 바로 표시 |
| See dose and time without opening Maru. | 不用打开 Maru，就能看到下次服药时间。 | Maruを開かずに、服用と時刻がわかります。 | Ve la dosis y la hora sin abrir Maru. | Dosis und Zeit sehen, ohne Maru zu öffnen. | Maru를 열지 않아도 복용 시간을 볼 수 있어요. |
| Record from your wrist | 在手腕上记录服药 | 手首から服用を記録 | Registra desde la muñeca | Am Handgelenk erfassen | 손목에서 바로 기록 |
| Tap Taken on Apple Watch. Needs iPhone. | 手表上点“已服用”，需连接 iPhone。 | 「服用済み」をタップ。iPhoneが必要です。 | Toca Tomado en el reloj. Necesita iPhone. | Tippe auf Eingenommen. iPhone nötig. | Apple Watch에서 ‘복용함’ 탭. iPhone 필요. |
| Make Maru yours | 打造你的 Maru | 自分らしいMaruに | Haz Maru tuya | Dein Maru, dein Stil | 나만의 Maru로 |
| App colors, icons, and reminder sounds. | 应用颜色、图标和提醒声音。 | アプリのカラー、アイコン、リマインダーの音。 | Colores, iconos y sonidos de recordatorio. | App-Farben, Symbole und Erinnerungstöne. | 앱 색상, 아이콘, 미리 알림 소리. |

## Family UI (D127)

These strings are new for the Family pages, the person menu of Today, the "For" row, "Add for…", and the Family headline of the paywall. No native speaker read them. The reviewer checks that "Family" does not read as Apple "Family Sharing", that a member name fits each title pattern, and that the Family headline fits two lines.

| English | zh-Hans | ja | es | de | ko |
|---|---|---|---|---|---|
| Family | 家人 | 家族 | Familia | Familie | 가족 |
| Everyone | 所有人 | みんな | Todos | Alle | 모두 |
| Show | 显示 | 表示 | Mostrar | Anzeigen | 표시 |
| Add Person or Pet | 添加家人或宠物 | 人やペットを追加 | Añadir persona o mascota | Person oder Tier hinzufügen | 사람 또는 반려동물 추가 |
| Add for… | 为其他人添加… | ほかの人に追加… | Añadir para… | Hinzufügen für … | 다른 구성원에게 추가… |
| For | 给谁 | 対象 | Para | Für | 대상 |
| Records move with the item. | 记录会随药品一起移动。 | 記録も項目と一緒に移ります。 | Los registros se mueven con el elemento. | Die Aufzeichnungen wandern mit dem Eintrag. | 기록도 항목과 함께 옮겨져요. |
| Keep doses and records for the people and pets you care for, each on their own. | 为你照顾的人和宠物分别管理用药和记录。 | 大切な人やペットの服用と記録を、それぞれ別に管理できます。 | Lleva las dosis y los registros de las personas y mascotas que cuidas, cada uno por separado. | Behalte Einnahmen und Aufzeichnungen der Menschen und Tiere, um die du dich kümmerst, getrennt im Blick. | 돌보는 사람과 반려동물의 복용과 기록을 각각 따로 관리해요. |
| Each one has their own items, reminders, and records. Nothing leaves this iPhone. | 每位成员都有自己的药品、提醒和记录。所有数据都只留在这台 iPhone 上。 | それぞれに項目、リマインダー、記録があります。データがこのiPhoneの外に出ることはありません。 | Cada uno tiene sus propios elementos, recordatorios y registros. Nada sale de este iPhone. | Alle haben eigene Einträge, Erinnerungen und Aufzeichnungen. Nichts verlässt dieses iPhone. | 각자 항목, 미리 알림, 기록을 따로 가져요. 어떤 데이터도 이 iPhone 밖으로 나가지 않아요. |
| New Person | 新成员 | 新しいメンバー | Nueva persona | Neue Person | 새 구성원 |
| New Pet | 新宠物 | 新しいペット | Nueva mascota | Neues Tier | 새 반려동물 |
| Person | 人 | 人 | Persona | Person | 사람 |
| Pet | 宠物 | ペット | Mascota | Haustier | 반려동물 |
| Kind | 类型 | 種類 | Tipo | Art | 종류 |
| Animal | 动物 | 動物 | Animal | Tier | 동물 |
| Dog | 狗 | 犬 | Perro | Hund | 개 |
| Cat | 猫 | 猫 | Gato | Katze | 고양이 |
| Bird | 鸟 | 鳥 | Pájaro | Vogel | 새 |
| Rabbit | 兔子 | ウサギ | Conejo | Kaninchen | 토끼 |
| Fish | 鱼 | 魚 | Pez | Fisch | 물고기 |
| Other Animal | 其他动物 | その他の動物 | Otro animal | Anderes Tier | 기타 동물 |
| Add Photo | 添加照片 | 写真を追加 | Añadir foto | Foto hinzufügen | 사진 추가 |
| Edit Photo | 编辑照片 | 写真を編集 | Editar foto | Foto bearbeiten | 사진 편집 |
| Delete | 删除 | 削除 | Eliminar | Löschen | 삭제 |
| Delete… | 删除… | 削除… | Eliminar… | Löschen … | 삭제… |
| Archive %@ and Their Items? | 要归档“%@”及其药品吗？ | 「%@」とその項目をアーカイブしますか？ | ¿Archivar a %@ y sus elementos? | „%@“ und die zugehörigen Einträge archivieren? | “%@” 및 해당 항목을 보관할까요? |
| Delete %@ and Their Items? | 要删除“%@”及其药品吗？ | 「%@」とその項目を削除しますか？ | ¿Eliminar a %@ y sus elementos? | „%@“ und die zugehörigen Einträge löschen? | “%@” 및 해당 항목을 삭제할까요? |
| Their reminders stop. History keeps their records. | 提醒会停止。历史记录会保留其记录。 | リマインダーは止まります。記録は履歴に残ります。 | Sus recordatorios se detienen. El historial conserva sus registros. | Die Erinnerungen enden. Der Verlauf behält die Aufzeichnungen. | 미리 알림이 멈춰요. 기록은 내역에 남아요. |
| Every record of their items goes too. You can’t undo this. | 其药品的所有记录也会一起删除。此操作无法撤销。 | 項目のすべての記録も削除されます。この操作は取り消せません。 | También se eliminan todos los registros de sus elementos. No se puede deshacer. | Alle Aufzeichnungen der Einträge werden ebenfalls gelöscht. Das lässt sich nicht widerrufen. | 항목의 모든 기록도 함께 삭제돼요. 되돌릴 수 없어요. |
| Everyone you care for, in one place. | 你在乎的每个人，都在这里。 | 大切な人を、ひとつの場所に。 | Todos los que cuidas, en un solo lugar. | Alle, für die du sorgst, an einem Ort. | 아끼는 모든 이를 한곳에서. |
| %lld items | %lld 个药品 | %lld項目 | %lld elementos | %lld Einträge | %lld개 항목 |
