# Localization review

This file lists the 25 riskiest strings of each language, for a native speaker to check. It covers the first release in six languages (D059). English is the source.

A reviewer checks three things in each row. The meaning of dose, time, skip, and taken stays the same. The text gives no medical advice. The text is short and natural, in the words of Apple's own apps in that language.

A string that names the iPhone has a second form for the iPad, with the same words and the other device name (D065). Check both forms. The full text is in `App/Localizable.xcstrings`, `Widget/Localizable.xcstrings`, `App/InfoPlist.xcstrings`, and `Packages/MaruKit/Sources/MaruNotifications/Resources/Localizable.xcstrings`. To change a string, edit the catalog and keep the format specifiers (`%@`, `%lld`, `%1$@`). The reviewer's name and the date go in the table below after a check.

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
| 2 | Notification | Title of a follow-up reminder | Still to take | 仍待服用 |
| 3 | Notification | Action of a reminder | Taken | 已服用 |
| 4 | Notification | Body with names off | Open Maru to see your plan. | 打开 Maru 查看你的计划。 |
| 5 | Notification | Title after the action recorded nothing | Not recorded | 未记录 |
| 6 | Notification | Body after the action recorded nothing | Open Maru to record it. | 打开 Maru 以记录。 |
| 7 | Notification | Test notification | This is a test from Maru. | 这是来自 Maru 的测试通知。 |
| 8 | Dose wording | VoiceOver hint of a dose circle | Records it as taken. | 记录为已服用。 |
| 10 | Dose wording | Row text of a taken dose | Taken at %@ | 服用于 %@ |
| 11 | Dose wording | State of a skipped dose | Skipped | 已跳过 |
| 12 | Dose wording | A planned dose with no record | No record | 无记录 |
| 13 | Dose wording | Action of an as-needed item | Take Now | 立即服用 |
| 14 | Dose wording | Menu item: record at an earlier time | Taken Earlier… | 较早服用… |
| 15 | Alert | Delete confirmation | Maru deletes this item, its plan, and all its records. You can’t undo this. | Maru 会删除此项目、它的计划和所有记录。此操作无法撤销。 |
| 16 | Alert | Archive confirmation (not advice) | Maru stops its reminders and hides it from Today and My Items. Your records stay. This is not advice to stop taking it. | Maru 会停止它的提醒，并在“今天”和“我的项目”中隐藏它。你的记录会保留。这不是停止服用的建议。 |
| 17 | Alert | Restore confirmation | This backup replaces every item and record on this iPhone. You can’t undo this. | 此备份会替换这台 iPhone 上的所有项目和记录。此操作无法撤销。 |
| 18 | Alert | Restore confirmation title | Replace All Data? | 要替换所有数据吗？ |
| 19 | Alert | Restore not confirmed | Maru couldn’t confirm that your iPhone saved it. If your data looks wrong later, restore the backup again. | Maru 无法确认 iPhone 是否已存储。如果之后发现数据有误，请再次恢复备份。 |
| 20 | Footer | Settings: backup files | A backup moves everything to a new iPhone. The files have your item names and records and are not encrypted, so share them only with people you trust. | 备份可将所有内容迁移到新 iPhone。文件包含你的项目名称和记录，且未加密，请只与你信任的人共享。 |
| 21 | Footer | Settings: usage statistics | Maru shares counts of what you use, and never item names, doses, or times. | Maru 只共享使用次数，绝不包含项目名称、剂量或时间。 |
| 22 | Footer | Settings: limit of Until Recorded | Maru reminds you up to %lld times for each dose, until %@ at the latest. | 每次服用，Maru 最多提醒 %lld 次，最晚到 %@ 为止。 |
| 23 | Privacy notice | Notice outside the EU, the UK, and Switzerland | Maru shares counts of what you use, such as whether you recorded a dose. Never item names, doses, or times. You can turn this off in Settings. | Maru 会共享你使用功能的次数，例如是否记录了一次服用。绝不包含项目名称、剂量或时间。你可以随时在“设置”中关闭。 |
| 24 | Privacy notice | Notice in the EU, the UK, and Switzerland (opt-in) | Share counts of what you use, such as whether you recorded a dose. Never item names, doses, or times. You can change this in Settings. | 共享你使用功能的次数，例如是否记录了一次服用。绝不包含项目名称、剂量或时间。你可以随时在“设置”中更改。 |
| 25 | Permission | Camera permission prompt | Maru uses the camera to read the name on a label and to take a photo of an item. A label scan saves no photo. | Maru 使用相机读取标签上的名称，并为项目拍照。扫描标签不会存储照片。 |

## Japanese (ja)

| # | Area | Where | English | Translation |
|---|---|---|---|---|
| 1 | Notification | Title of a reminder | Time to take | 服用の時間です |
| 2 | Notification | Title of a follow-up reminder | Still to take | 服用がまだです |
| 3 | Notification | Action of a reminder | Taken | 服用済み |
| 4 | Notification | Body with names off | Open Maru to see your plan. | Maruを開いてプランを確認してください。 |
| 5 | Notification | Title after the action recorded nothing | Not recorded | 記録されていません |
| 6 | Notification | Body after the action recorded nothing | Open Maru to record it. | Maruを開いて記録してください。 |
| 7 | Notification | Test notification | This is a test from Maru. | Maruからのテスト通知です。 |
| 8 | Dose wording | VoiceOver hint of a dose circle | Records it as taken. | 服用として記録します。 |
| 10 | Dose wording | Row text of a taken dose | Taken at %@ | %@に服用 |
| 11 | Dose wording | State of a skipped dose | Skipped | スキップ済み |
| 12 | Dose wording | A planned dose with no record | No record | 記録なし |
| 13 | Dose wording | Action of an as-needed item | Take Now | 今すぐ服用 |
| 14 | Dose wording | Menu item: record at an earlier time | Taken Earlier… | 以前の服用… |
| 15 | Alert | Delete confirmation | Maru deletes this item, its plan, and all its records. You can’t undo this. | Maruはこの項目、プラン、すべての記録を削除します。この操作は取り消せません。 |
| 16 | Alert | Archive confirmation (not advice) | Maru stops its reminders and hides it from Today and My Items. Your records stay. This is not advice to stop taking it. | Maruはこの項目のリマインドを止め、「今日」と「マイ項目」から非表示にします。記録は残ります。これは服用をやめるための助言ではありません。 |
| 17 | Alert | Restore confirmation | This backup replaces every item and record on this iPhone. You can’t undo this. | このバックアップは、このiPhoneのすべての項目と記録を置き換えます。この操作は取り消せません。 |
| 18 | Alert | Restore confirmation title | Replace All Data? | すべてのデータを置き換えますか？ |
| 19 | Alert | Restore not confirmed | Maru couldn’t confirm that your iPhone saved it. If your data looks wrong later, restore the backup again. | iPhoneが保存したことをMaruが確認できませんでした。あとでデータがおかしい場合は、バックアップをもう一度復元してください。 |
| 20 | Footer | Settings: backup files | A backup moves everything to a new iPhone. The files have your item names and records and are not encrypted, so share them only with people you trust. | バックアップを使うと、すべてを新しいiPhoneに移せます。ファイルには項目名と記録が含まれ、暗号化されていません。信頼できる相手とだけ共有してください。 |
| 21 | Footer | Settings: usage statistics | Maru shares counts of what you use, and never item names, doses, or times. | Maruが共有するのは利用した回数だけです。項目名、用量、時刻は共有しません。 |
| 22 | Footer | Settings: limit of Until Recorded | Maru reminds you up to %lld times for each dose, until %@ at the latest. | Maruは1回の服用につき最大%lld回、遅くとも%@までリマインドします。 |
| 23 | Privacy notice | Notice outside the EU, the UK, and Switzerland | Maru shares counts of what you use, such as whether you recorded a dose. Never item names, doses, or times. You can turn this off in Settings. | Maruは、服用を記録したかどうかなど、機能を使った回数を共有します。項目名、用量、時刻は共有しません。「設定」でいつでもオフにできます。 |
| 24 | Privacy notice | Notice in the EU, the UK, and Switzerland (opt-in) | Share counts of what you use, such as whether you recorded a dose. Never item names, doses, or times. You can change this in Settings. | 服用を記録したかどうかなど、機能を使った回数を共有します。項目名、用量、時刻は共有しません。この設定は「設定」でいつでも変更できます。 |
| 25 | Permission | Camera permission prompt | Maru uses the camera to read the name on a label and to take a photo of an item. A label scan saves no photo. | Maruはカメラを使って、ラベルの名前を読み取ったり、項目の写真を撮ったりします。ラベルのスキャンでは写真を保存しません。 |

## Spanish (es)

| # | Area | Where | English | Translation |
|---|---|---|---|---|
| 1 | Notification | Title of a reminder | Time to take | Hora de tomar |
| 2 | Notification | Title of a follow-up reminder | Still to take | Pendiente de tomar |
| 3 | Notification | Action of a reminder | Taken | Tomado |
| 4 | Notification | Body with names off | Open Maru to see your plan. | Abre Maru para ver tu plan. |
| 5 | Notification | Title after the action recorded nothing | Not recorded | No registrado |
| 6 | Notification | Body after the action recorded nothing | Open Maru to record it. | Abre Maru para registrarlo. |
| 7 | Notification | Test notification | This is a test from Maru. | Esta es una prueba de Maru. |
| 8 | Dose wording | VoiceOver hint of a dose circle | Records it as taken. | La registra como tomada. |
| 10 | Dose wording | Row text of a taken dose | Taken at %@ | Tomado: %@ |
| 11 | Dose wording | State of a skipped dose | Skipped | Omitido |
| 12 | Dose wording | A planned dose with no record | No record | Sin registro |
| 13 | Dose wording | Action of an as-needed item | Take Now | Tomar ahora |
| 14 | Dose wording | Menu item: record at an earlier time | Taken Earlier… | Tomado antes… |
| 15 | Alert | Delete confirmation | Maru deletes this item, its plan, and all its records. You can’t undo this. | Maru elimina este elemento, su plan y todos sus registros. No se puede deshacer. |
| 16 | Alert | Archive confirmation (not advice) | Maru stops its reminders and hides it from Today and My Items. Your records stay. This is not advice to stop taking it. | Maru detiene sus recordatorios y lo oculta de Hoy y de Mis elementos. Tus registros se conservan. Esto no es una recomendación de dejar de tomarlo. |
| 17 | Alert | Restore confirmation | This backup replaces every item and record on this iPhone. You can’t undo this. | Esta copia de seguridad reemplaza todos los elementos y registros de este iPhone. No se puede deshacer. |
| 18 | Alert | Restore confirmation title | Replace All Data? | ¿Reemplazar todos los datos? |
| 19 | Alert | Restore not confirmed | Maru couldn’t confirm that your iPhone saved it. If your data looks wrong later, restore the backup again. | Maru no ha podido confirmar que el iPhone lo guardara. Si más adelante tus datos parecen incorrectos, restaura la copia de seguridad otra vez. |
| 20 | Footer | Settings: backup files | A backup moves everything to a new iPhone. The files have your item names and records and are not encrypted, so share them only with people you trust. | Una copia de seguridad lo traslada todo a un iPhone nuevo. Los archivos contienen los nombres de tus elementos y tus registros, y no están cifrados. Compártelos solo con personas de confianza. |
| 21 | Footer | Settings: usage statistics | Maru shares counts of what you use, and never item names, doses, or times. | Maru comparte recuentos de uso, nunca nombres de elementos, dosis ni horas. |
| 22 | Footer | Settings: limit of Until Recorded | Maru reminds you up to %lld times for each dose, until %@ at the latest. | Maru te recuerda hasta %lld veces por dosis. Límite: %@. |
| 23 | Privacy notice | Notice outside the EU, the UK, and Switzerland | Maru shares counts of what you use, such as whether you recorded a dose. Never item names, doses, or times. You can turn this off in Settings. | Maru comparte recuentos de lo que usas, como si has registrado una dosis. Nunca nombres de elementos, dosis ni horas. Puedes desactivarlo en Ajustes. |
| 24 | Privacy notice | Notice in the EU, the UK, and Switzerland (opt-in) | Share counts of what you use, such as whether you recorded a dose. Never item names, doses, or times. You can change this in Settings. | Comparte recuentos de lo que usas, como si has registrado una dosis. Nunca nombres de elementos, dosis ni horas. Puedes cambiarlo en Ajustes. |
| 25 | Permission | Camera permission prompt | Maru uses the camera to read the name on a label and to take a photo of an item. A label scan saves no photo. | Maru usa la cámara para leer el nombre de una etiqueta y para hacer una foto de un elemento. El escaneo de una etiqueta no guarda ninguna foto. |

## German (de)

| # | Area | Where | English | Translation |
|---|---|---|---|---|
| 1 | Notification | Title of a reminder | Time to take | Zeit zur Einnahme |
| 2 | Notification | Title of a follow-up reminder | Still to take | Noch einzunehmen |
| 3 | Notification | Action of a reminder | Taken | Eingenommen |
| 4 | Notification | Body with names off | Open Maru to see your plan. | Öffne Maru, um deinen Plan zu sehen. |
| 5 | Notification | Title after the action recorded nothing | Not recorded | Nicht erfasst |
| 6 | Notification | Body after the action recorded nothing | Open Maru to record it. | Öffne Maru, um es zu erfassen. |
| 7 | Notification | Test notification | This is a test from Maru. | Das ist ein Test von Maru. |
| 8 | Dose wording | VoiceOver hint of a dose circle | Records it as taken. | Erfasst sie als eingenommen. |
| 10 | Dose wording | Row text of a taken dose | Taken at %@ | Eingenommen: %@ |
| 11 | Dose wording | State of a skipped dose | Skipped | Übersprungen |
| 12 | Dose wording | A planned dose with no record | No record | Keine Aufzeichnung |
| 13 | Dose wording | Action of an as-needed item | Take Now | Jetzt einnehmen |
| 14 | Dose wording | Menu item: record at an earlier time | Taken Earlier… | Früher eingenommen … |
| 15 | Alert | Delete confirmation | Maru deletes this item, its plan, and all its records. You can’t undo this. | Maru löscht diesen Eintrag, seinen Plan und alle seine Aufzeichnungen. Das kannst du nicht rückgängig machen. |
| 16 | Alert | Archive confirmation (not advice) | Maru stops its reminders and hides it from Today and My Items. Your records stay. This is not advice to stop taking it. | Maru beendet seine Erinnerungen und blendet ihn in Heute und Meine Einträge aus. Deine Aufzeichnungen bleiben. Das ist keine Empfehlung, die Einnahme zu beenden. |
| 17 | Alert | Restore confirmation | This backup replaces every item and record on this iPhone. You can’t undo this. | Dieses Backup ersetzt alle Einträge und Aufzeichnungen auf diesem iPhone. Das kannst du nicht rückgängig machen. |
| 18 | Alert | Restore confirmation title | Replace All Data? | Alle Daten ersetzen? |
| 19 | Alert | Restore not confirmed | Maru couldn’t confirm that your iPhone saved it. If your data looks wrong later, restore the backup again. | Maru konnte nicht bestätigen, dass dein iPhone die Daten gesichert hat. Wenn deine Daten später falsch aussehen, stelle das Backup erneut wieder her. |
| 20 | Footer | Settings: backup files | A backup moves everything to a new iPhone. The files have your item names and records and are not encrypted, so share them only with people you trust. | Ein Backup überträgt alles auf ein neues iPhone. Die Dateien enthalten die Namen deiner Einträge und deine Aufzeichnungen und sind nicht verschlüsselt. Teile sie nur mit Personen, denen du vertraust. |
| 21 | Footer | Settings: usage statistics | Maru shares counts of what you use, and never item names, doses, or times. | Maru teilt nur Zählwerte zur Nutzung, nie Namen, Dosen oder Zeiten. |
| 22 | Footer | Settings: limit of Until Recorded | Maru reminds you up to %lld times for each dose, until %@ at the latest. | Maru erinnert dich bis zu %lld Mal pro Dosis, spätestens bis %@. |
| 23 | Privacy notice | Notice outside the EU, the UK, and Switzerland | Maru shares counts of what you use, such as whether you recorded a dose. Never item names, doses, or times. You can turn this off in Settings. | Maru teilt Zählwerte zur Nutzung, zum Beispiel ob du eine Dosis erfasst hast. Nie Namen, Dosen oder Zeiten. Du kannst das in den Einstellungen ausschalten. |
| 24 | Privacy notice | Notice in the EU, the UK, and Switzerland (opt-in) | Share counts of what you use, such as whether you recorded a dose. Never item names, doses, or times. You can change this in Settings. | Teile Zählwerte zur Nutzung, zum Beispiel ob du eine Dosis erfasst hast. Nie Namen, Dosen oder Zeiten. Du kannst das in den Einstellungen ändern. |
| 25 | Permission | Camera permission prompt | Maru uses the camera to read the name on a label and to take a photo of an item. A label scan saves no photo. | Maru verwendet die Kamera, um den Namen auf einem Etikett zu lesen und ein Foto eines Eintrags aufzunehmen. Ein Etikett-Scan speichert kein Foto. |

## Korean (ko)

| # | Area | Where | English | Translation |
|---|---|---|---|---|
| 1 | Notification | Title of a reminder | Time to take | 복용할 시간 |
| 2 | Notification | Title of a follow-up reminder | Still to take | 아직 복용 전 |
| 3 | Notification | Action of a reminder | Taken | 복용함 |
| 4 | Notification | Body with names off | Open Maru to see your plan. | Maru를 열어 계획을 확인하세요. |
| 5 | Notification | Title after the action recorded nothing | Not recorded | 기록되지 않음 |
| 6 | Notification | Body after the action recorded nothing | Open Maru to record it. | Maru를 열어 기록하세요. |
| 7 | Notification | Test notification | This is a test from Maru. | Maru의 테스트 알림이에요. |
| 8 | Dose wording | VoiceOver hint of a dose circle | Records it as taken. | 복용함으로 기록해요. |
| 10 | Dose wording | Row text of a taken dose | Taken at %@ | 복용 시간: %@ |
| 11 | Dose wording | State of a skipped dose | Skipped | 건너뜀 |
| 12 | Dose wording | A planned dose with no record | No record | 기록 없음 |
| 13 | Dose wording | Action of an as-needed item | Take Now | 지금 복용 |
| 14 | Dose wording | Menu item: record at an earlier time | Taken Earlier… | 앞서 복용함… |
| 15 | Alert | Delete confirmation | Maru deletes this item, its plan, and all its records. You can’t undo this. | Maru가 이 항목과 계획, 모든 기록을 삭제해요. 이 동작은 되돌릴 수 없어요. |
| 16 | Alert | Archive confirmation (not advice) | Maru stops its reminders and hides it from Today and My Items. Your records stay. This is not advice to stop taking it. | Maru가 이 항목의 미리 알림을 멈추고 오늘과 내 항목에서 숨겨요. 기록은 그대로 남아요. 복용을 멈추라는 조언이 아니에요. |
| 17 | Alert | Restore confirmation | This backup replaces every item and record on this iPhone. You can’t undo this. | 이 백업은 이 iPhone의 모든 항목과 기록을 교체해요. 이 동작은 되돌릴 수 없어요. |
| 18 | Alert | Restore confirmation title | Replace All Data? | 모든 데이터를 교체할까요? |
| 19 | Alert | Restore not confirmed | Maru couldn’t confirm that your iPhone saved it. If your data looks wrong later, restore the backup again. | iPhone이 저장했는지 Maru가 확인하지 못했어요. 나중에 데이터가 이상하면 백업을 다시 복원하세요. |
| 20 | Footer | Settings: backup files | A backup moves everything to a new iPhone. The files have your item names and records and are not encrypted, so share them only with people you trust. | 백업하면 모든 내용을 새 iPhone으로 옮길 수 있어요. 파일에는 항목 이름과 기록이 들어 있고 암호화되지 않으니, 믿을 수 있는 사람과만 공유하세요. |
| 21 | Footer | Settings: usage statistics | Maru shares counts of what you use, and never item names, doses, or times. | Maru는 사용 횟수만 공유해요. 항목 이름, 용량, 시간은 절대 공유하지 않아요. |
| 22 | Footer | Settings: limit of Until Recorded | Maru reminds you up to %lld times for each dose, until %@ at the latest. | Maru는 복용 1회당 최대 %lld번, 늦어도 %@까지 미리 알려줘요. |
| 23 | Privacy notice | Notice outside the EU, the UK, and Switzerland | Maru shares counts of what you use, such as whether you recorded a dose. Never item names, doses, or times. You can turn this off in Settings. | Maru는 복용을 기록했는지 같은 사용 횟수를 공유해요. 항목 이름, 용량, 시간은 절대 공유하지 않아요. 설정에서 언제든 끌 수 있어요. |
| 24 | Privacy notice | Notice in the EU, the UK, and Switzerland (opt-in) | Share counts of what you use, such as whether you recorded a dose. Never item names, doses, or times. You can change this in Settings. | 복용을 기록했는지 같은 사용 횟수를 공유해요. 항목 이름, 용량, 시간은 절대 공유하지 않아요. 설정에서 언제든 바꿀 수 있어요. |
| 25 | Permission | Camera permission prompt | Maru uses the camera to read the name on a label and to take a photo of an item. A label scan saves no photo. | Maru는 카메라로 라벨의 이름을 읽고 항목 사진을 찍어요. 라벨 스캔은 사진을 저장하지 않아요. |
