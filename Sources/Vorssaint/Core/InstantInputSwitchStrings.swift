// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Volod1ka

import Foundation

struct InstantInputSwitchStrings {
    let pageTitle: String
    let hubDescription: String
    let enableToggle: String
    let enableCaption: String
    let triggerLabel: String
    let triggerControlSpace: String
    let triggerFn: String
    let triggerRightCommand: String
    let triggerRightOption: String
    let noteControlSpace: String
    let noteFn: String
    let noteModifier: String
    /// "Press 🌐 key to" is "Do Nothing": only UnTangle acts on a tap.
    let fnUsageReady: String
    let fnUsageChangesInputSource: String
    let fnUsageOther: String
    let fnUsageUnknown: String
    let openKeyboardSettings: String
    let superKeyConflict: String
    let activeNow: String
    let guardSection: String
    let guardToggle: String
    let guardCaption: String
    let strategyLabel: String
    let strategyRewrite: String
    let strategyReplay: String
    let strategyCaption: String
    let windowLabel: String
    let millisecondsFormat: String
    let indicatorSection: String
    let indicatorToggle: String
    let indicatorCaption: String
    let manageButton: String

    func triggerLabel(_ trigger: InstantInputSwitchTrigger) -> String {
        switch trigger {
        case .controlSpace: return triggerControlSpace
        case .fn: return triggerFn
        case .rightCommand: return triggerRightCommand
        case .rightOption: return triggerRightOption
        }
    }

    func triggerNote(_ trigger: InstantInputSwitchTrigger) -> String {
        switch trigger {
        case .controlSpace: return noteControlSpace
        case .fn: return noteFn
        case .rightCommand, .rightOption: return noteModifier
        }
    }

    func strategyLabel(_ strategy: InputSourceGuardStrategy) -> String {
        switch strategy {
        case .rewrite: return strategyRewrite
        case .replay: return strategyReplay
        }
    }

    /// What the page says about macOS's own use of 🌐.
    func fnUsageNote(_ usage: InstantInputSwitchSupport.FnKeyUsage) -> String {
        switch usage {
        case .doNothing: return fnUsageReady
        case .changeInputSource: return fnUsageChangesInputSource
        case .emojiAndSymbols, .dictation: return fnUsageOther
        case .unknown: return fnUsageUnknown
        }
    }
}

extension FeatureStrings {
    static func instantInputSwitch(_ language: AppLanguage) -> InstantInputSwitchStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .uk: return .uk
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        }
    }
}

extension InstantInputSwitchStrings {
    static let enUS = InstantInputSwitchStrings(
        pageTitle: "Instant input switch",
        hubDescription: "Switches the keyboard language at once and keeps the first letters you type right after it in the new language.",
        enableToggle: "Switch input sources with UnTangle",
        enableCaption: "macOS changes the language at once, but apps catch up later, so the first letters after a switch can come out in the old one. UnTangle switches on its own key and fixes those letters.",
        triggerLabel: "Switch with",
        triggerControlSpace: "Control-Space",
        triggerFn: "Fn (🌐) tapped on its own",
        triggerRightCommand: "Right ⌘ tapped on its own",
        triggerRightOption: "Right ⌥ tapped on its own",
        noteControlSpace: "UnTangle takes Control-Space over from macOS while this is on and gives it back when it is off, or while a password field is focused. Like in macOS, it goes back to the previous language; the other keys go on to the next one in the list.",
        noteFn: "Only a quick tap of 🌐 with no other key switches. Fn shortcuts keep working.",
        noteModifier: "Only a quick tap with no other key switches. The key keeps working as a modifier.",
        fnUsageReady: "“Press 🌐 key to” (“Press fn key to”) is set to “Do Nothing”, so only UnTangle switches.",
        fnUsageChangesInputSource: "macOS switches the language on 🌐 as well, so it would switch back. Set “Press 🌐 key to” (“Press fn key to”) to “Do Nothing” in System Settings › Keyboard.",
        fnUsageOther: "macOS also uses 🌐 for emoji or dictation. Set “Press 🌐 key to” (“Press fn key to”) to “Do Nothing” in System Settings › Keyboard so a tap only switches the language.",
        fnUsageUnknown: "UnTangle cannot tell what macOS does on 🌐. Make sure “Press 🌐 key to” (“Press fn key to”) is set to “Do Nothing” in System Settings › Keyboard.",
        openKeyboardSettings: "Open Keyboard Settings…",
        superKeyConflict: "The Super key uses this key, so the switch never sees it. Choose another key here or for the Super key.",
        activeNow: "Working now",
        guardSection: "First letters after a switch",
        guardToggle: "Keep the first letters in the new language",
        guardCaption: "For a moment after each switch, UnTangle makes sure the keys you type come out in the new language, even in an app that has not caught up yet. Shortcuts with ⌘ or ⌃ are never touched. While this feature is installed, the same settings apply when the Super key switches the input source.",
        strategyLabel: "Method",
        strategyRewrite: "Type the new letter (instant)",
        strategyReplay: "Hold the keys and send them again",
        strategyCaption: "Typing the new letter adds no delay but works with keyboard layouts only; a switch to an input method always holds the keys. Holding works everywhere but delays those keys by the window below.",
        windowLabel: "Window",
        millisecondsFormat: "%d ms",
        indicatorSection: "Language indicator",
        indicatorToggle: "Show the macOS language indicator next to the cursor",
        indicatorCaption: "macOS shows the input source next to the text cursor after every switch. Turning it off can make switching feel quicker. This is a macOS setting: it takes effect after you log out and back in, and stays as set even without UnTangle.",
        manageButton: "Set up…"
    )

    static let ptBR = InstantInputSwitchStrings(
        pageTitle: "Troca instantânea de idioma",
        hubDescription: "Troca o idioma do teclado na hora e mantém no novo idioma as primeiras letras digitadas logo depois.",
        enableToggle: "Trocar fontes de entrada com o UnTangle",
        enableCaption: "O macOS troca o idioma na hora, mas os apps só acompanham depois, então as primeiras letras após a troca podem sair no idioma anterior. O UnTangle troca com a própria tecla e corrige essas letras.",
        triggerLabel: "Trocar com",
        triggerControlSpace: "Control-Espaço",
        triggerFn: "Fn (🌐) pressionada sozinha",
        triggerRightCommand: "⌘ direito pressionado sozinho",
        triggerRightOption: "⌥ direito pressionado sozinho",
        noteControlSpace: "Enquanto isto estiver ativo, o UnTangle assume o Control-Espaço do macOS e o devolve quando for desativado ou quando um campo de senha estiver em foco. Como no macOS, ele volta ao idioma anterior; as outras teclas avançam para o próximo da lista.",
        noteFn: "Só um toque rápido em 🌐, sem outra tecla, troca o idioma. Os atalhos com Fn continuam funcionando.",
        noteModifier: "Só um toque rápido, sem outra tecla, troca o idioma. A tecla continua funcionando como modificadora.",
        fnUsageReady: "“Pressionar a tecla 🌐 para” (“Pressione a tecla fn para”) está em “Não Fazer Nada”, então só o UnTangle troca o idioma.",
        fnUsageChangesInputSource: "O macOS também troca o idioma na tecla 🌐, então ele voltaria. Em Ajustes › Teclado, defina “Pressionar a tecla 🌐 para” (“Pressione a tecla fn para”) como “Não Fazer Nada”.",
        fnUsageOther: "O macOS também usa 🌐 para emoji ou ditado. Em Ajustes › Teclado, defina “Pressionar a tecla 🌐 para” (“Pressione a tecla fn para”) como “Não Fazer Nada” para que um toque só troque o idioma.",
        fnUsageUnknown: "O UnTangle não consegue saber o que o macOS faz na tecla 🌐. Confira em Ajustes › Teclado se “Pressionar a tecla 🌐 para” (“Pressione a tecla fn para”) está em “Não Fazer Nada”.",
        openKeyboardSettings: "Abrir Ajustes de Teclado…",
        superKeyConflict: "A tecla super usa esta tecla, então a troca nunca a recebe. Escolha outra tecla aqui ou para a tecla super.",
        activeNow: "Funcionando agora",
        guardSection: "Primeiras letras após a troca",
        guardToggle: "Manter as primeiras letras no novo idioma",
        guardCaption: "Por um instante após cada troca, o UnTangle garante que as teclas digitadas saiam no novo idioma, mesmo num app que ainda não acompanhou. Atalhos com ⌘ ou ⌃ nunca são alterados. Enquanto este recurso estiver instalado, os mesmos ajustes valem quando a tecla super troca a fonte de entrada.",
        strategyLabel: "Método",
        strategyRewrite: "Digitar a nova letra (instantâneo)",
        strategyReplay: "Segurar as teclas e enviá-las de novo",
        strategyCaption: "Digitar a nova letra não causa atraso, mas só funciona com layouts de teclado; ao trocar para um método de entrada, as teclas são sempre seguradas. Segurar funciona em qualquer caso, mas atrasa essas teclas pela janela abaixo.",
        windowLabel: "Janela",
        millisecondsFormat: "%d ms",
        indicatorSection: "Indicador de idioma",
        indicatorToggle: "Mostrar o indicador de idioma do macOS junto ao cursor",
        indicatorCaption: "O macOS mostra a fonte de entrada junto ao cursor de texto após cada troca. Desativá-lo pode deixar a troca mais ágil. É um ajuste do macOS: vale depois de encerrar a sessão e entrar de novo, e continua assim mesmo sem o UnTangle.",
        manageButton: "Configurar…"
    )

    static let tr = InstantInputSwitchStrings(
        pageTitle: "Anında dil değiştirme",
        hubDescription: "Klavye dilini anında değiştirir ve hemen ardından yazılan ilk harfleri yeni dilde tutar.",
        enableToggle: "Giriş kaynaklarını UnTangle ile değiştir",
        enableCaption: "macOS dili anında değiştirir ama uygulamalar daha sonra yetişir; bu yüzden değişiklikten sonraki ilk harfler eski dilde çıkabilir. UnTangle kendi tuşuyla değiştirir ve bu harfleri düzeltir.",
        triggerLabel: "Değiştirme tuşu",
        triggerControlSpace: "Control-Boşluk",
        triggerFn: "Tek başına basılan Fn (🌐)",
        triggerRightCommand: "Tek başına basılan sağ ⌘",
        triggerRightOption: "Tek başına basılan sağ ⌥",
        noteControlSpace: "Bu açıkken UnTangle, Control-Boşluk kısayolunu macOS’ten devralır; kapatıldığında veya bir parola alanı etkinken geri verir. macOS’te olduğu gibi önceki dile döner; diğer tuşlar listedeki bir sonrakine geçer.",
        noteFn: "Yalnızca başka tuş olmadan 🌐 tuşuna kısa basmak dili değiştirir. Fn kısayolları çalışmaya devam eder.",
        noteModifier: "Yalnızca başka tuş olmadan kısa basmak dili değiştirir. Tuş, değiştirici tuş olarak çalışmaya devam eder.",
        fnUsageReady: "“🌐 tuşuna basıldığında” (“Fn tuşuna basıldığında”) ayarı “Hiçbir Şey Yapma” olarak seçili; dili yalnızca UnTangle değiştirir.",
        fnUsageChangesInputSource: "macOS da 🌐 tuşunda dili değiştirir, bu yüzden dil geri döner. Sistem Ayarları › Klavye’de “🌐 tuşuna basıldığında” (“Fn tuşuna basıldığında”) ayarını “Hiçbir Şey Yapma” yapın.",
        fnUsageOther: "macOS 🌐 tuşunu emoji veya dikte için de kullanıyor. Kısa basış yalnızca dili değiştirsin diye Sistem Ayarları › Klavye’de “🌐 tuşuna basıldığında” (“Fn tuşuna basıldığında”) ayarını “Hiçbir Şey Yapma” yapın.",
        fnUsageUnknown: "UnTangle, macOS’in 🌐 tuşunda ne yaptığını anlayamıyor. Sistem Ayarları › Klavye’de “🌐 tuşuna basıldığında” (“Fn tuşuna basıldığında”) ayarının “Hiçbir Şey Yapma” olduğundan emin olun.",
        openKeyboardSettings: "Klavye Ayarlarını Aç…",
        superKeyConflict: "Süper tuş bu tuşu kullanıyor, bu yüzden dil değiştirme onu hiç görmüyor. Burada ya da süper tuş için başka bir tuş seçin.",
        activeNow: "Şu anda çalışıyor",
        guardSection: "Değiştirdikten sonraki ilk harfler",
        guardToggle: "İlk harfleri yeni dilde tut",
        guardCaption: "Her değişiklikten sonra kısa bir süre UnTangle, yazdığınız tuşların henüz yetişmemiş bir uygulamada bile yeni dilde çıkmasını sağlar. ⌘ veya ⌃ içeren kısayollara asla dokunulmaz. Bu özellik yüklü olduğu sürece, süper tuş giriş kaynağını değiştirdiğinde de aynı ayarlar geçerlidir.",
        strategyLabel: "Yöntem",
        strategyRewrite: "Yeni harfi yaz (anında)",
        strategyReplay: "Tuşları tut ve yeniden gönder",
        strategyCaption: "Yeni harfi yazmak gecikme eklemez ama yalnızca klavye düzenleriyle çalışır; bir giriş yöntemine geçişte tuşlar her zaman tutulur. Tutmak her yerde çalışır ama bu tuşları aşağıdaki süre kadar geciktirir.",
        windowLabel: "Süre",
        millisecondsFormat: "%d ms",
        indicatorSection: "Dil göstergesi",
        indicatorToggle: "macOS dil göstergesini imlecin yanında göster",
        indicatorCaption: "macOS her değişiklikten sonra giriş kaynağını metin imlecinin yanında gösterir. Kapatmak geçişi daha hızlı hissettirebilir. Bu bir macOS ayarıdır: oturumu kapatıp yeniden açtıktan sonra geçerli olur ve UnTangle olmadan da öyle kalır.",
        manageButton: "Ayarla…"
    )

    static let ru = InstantInputSwitchStrings(
        pageTitle: "Мгновенное переключение языка",
        hubDescription: "Переключает язык клавиатуры сразу и сохраняет первые буквы после переключения на новом языке.",
        enableToggle: "Переключать источники ввода через UnTangle",
        enableCaption: "macOS меняет язык сразу, но программы подхватывают его позже, поэтому первые буквы после переключения могут выйти на старом языке. UnTangle переключает своей клавишей и исправляет эти буквы.",
        triggerLabel: "Переключать",
        triggerControlSpace: "Control-Пробел",
        triggerFn: "Отдельным нажатием Fn (🌐)",
        triggerRightCommand: "Отдельным нажатием правого ⌘",
        triggerRightOption: "Отдельным нажатием правого ⌥",
        noteControlSpace: "Пока функция включена, UnTangle забирает Control-Пробел у macOS и возвращает его, когда функция выключена или когда активно поле пароля. Как и в macOS, он возвращает предыдущий язык; остальные клавиши переключают на следующий в списке.",
        noteFn: "Переключает только короткое нажатие 🌐 без других клавиш. Сочетания с Fn продолжают работать.",
        noteModifier: "Переключает только короткое нажатие без других клавиш. Как модификатор клавиша работает как прежде.",
        fnUsageReady: "Для «Нажатие клавиши 🌐» («Нажатие клавиши Fn») выбрано «действие не требуется», поэтому язык переключает только UnTangle.",
        fnUsageChangesInputSource: "macOS тоже переключает язык по 🌐, и он вернётся обратно. В «Системные настройки › Клавиатура» для «Нажатие клавиши 🌐» («Нажатие клавиши Fn») выберите «действие не требуется».",
        fnUsageOther: "macOS также использует 🌐 для эмодзи или диктовки. В «Системные настройки › Клавиатура» для «Нажатие клавиши 🌐» («Нажатие клавиши Fn») выберите «действие не требуется», чтобы нажатие только переключало язык.",
        fnUsageUnknown: "UnTangle не может определить, что macOS делает по 🌐. Убедитесь, что в «Системные настройки › Клавиатура» для «Нажатие клавиши 🌐» («Нажатие клавиши Fn») выбрано «действие не требуется».",
        openKeyboardSettings: "Открыть настройки клавиатуры…",
        superKeyConflict: "Эту клавишу использует суперклавиша, поэтому переключение её не видит. Выберите другую клавишу здесь или для суперклавиши.",
        activeNow: "Работает",
        guardSection: "Первые буквы после переключения",
        guardToggle: "Сохранять первые буквы на новом языке",
        guardCaption: "В течение короткого времени после каждого переключения UnTangle следит, чтобы нажатые клавиши выходили на новом языке, даже если программа ещё не успела переключиться. Сочетания с ⌘ или ⌃ не изменяются. Пока эта функция установлена, те же настройки действуют, когда язык переключает суперклавиша.",
        strategyLabel: "Способ",
        strategyRewrite: "Подставлять новую букву (мгновенно)",
        strategyReplay: "Задерживать клавиши и отправлять повторно",
        strategyCaption: "Подстановка не добавляет задержки, но работает только с раскладками; при переключении на метод ввода клавиши всегда задерживаются. Задержка работает везде, но откладывает эти клавиши на окно ниже.",
        windowLabel: "Окно",
        millisecondsFormat: "%d мс",
        indicatorSection: "Индикатор языка",
        indicatorToggle: "Показывать индикатор языка macOS у курсора",
        indicatorCaption: "После каждого переключения macOS показывает источник ввода рядом с текстовым курсором. Если его выключить, переключение может ощущаться быстрее. Это настройка macOS: она вступает в силу после выхода из системы и повторного входа и сохраняется даже без UnTangle.",
        manageButton: "Настроить…"
    )

    static let es = InstantInputSwitchStrings(
        pageTitle: "Cambio instantáneo de idioma",
        hubDescription: "Cambia el idioma del teclado al instante y mantiene en el nuevo idioma las primeras letras que escribes justo después.",
        enableToggle: "Cambiar fuentes de entrada con UnTangle",
        enableCaption: "macOS cambia el idioma al instante, pero las apps lo aplican más tarde, así que las primeras letras tras el cambio pueden salir en el idioma anterior. UnTangle cambia con su propia tecla y corrige esas letras.",
        triggerLabel: "Cambiar con",
        triggerControlSpace: "Control-Espacio",
        triggerFn: "Fn (🌐) pulsada sola",
        triggerRightCommand: "⌘ derecha pulsada sola",
        triggerRightOption: "⌥ derecha pulsada sola",
        noteControlSpace: "Mientras esté activado, UnTangle toma Control-Espacio de macOS y lo devuelve al desactivarlo o mientras haya un campo de contraseña activo. Como en macOS, vuelve al idioma anterior; las demás teclas pasan al siguiente de la lista.",
        noteFn: "Solo una pulsación breve de 🌐 sin otra tecla cambia el idioma. Los atajos con Fn siguen funcionando.",
        noteModifier: "Solo una pulsación breve sin otra tecla cambia el idioma. La tecla sigue funcionando como modificadora.",
        fnUsageReady: "“Acción al pulsar la tecla 🌐” (“Acción al pulsar la tecla fn”) está en “No hacer nada”, así que solo UnTangle cambia el idioma.",
        fnUsageChangesInputSource: "macOS también cambia el idioma con 🌐, así que volvería al anterior. En Ajustes del Sistema › Teclado, pon “Acción al pulsar la tecla 🌐” (“Acción al pulsar la tecla fn”) en “No hacer nada”.",
        fnUsageOther: "macOS también usa 🌐 para emojis o dictado. En Ajustes del Sistema › Teclado, pon “Acción al pulsar la tecla 🌐” (“Acción al pulsar la tecla fn”) en “No hacer nada” para que una pulsación solo cambie el idioma.",
        fnUsageUnknown: "UnTangle no puede saber qué hace macOS con 🌐. Comprueba en Ajustes del Sistema › Teclado que “Acción al pulsar la tecla 🌐” (“Acción al pulsar la tecla fn”) esté en “No hacer nada”.",
        openKeyboardSettings: "Abrir ajustes de teclado…",
        superKeyConflict: "La tecla súper usa esta tecla, así que el cambio nunca la recibe. Elige otra tecla aquí o para la tecla súper.",
        activeNow: "Funcionando ahora",
        guardSection: "Primeras letras tras el cambio",
        guardToggle: "Mantener las primeras letras en el nuevo idioma",
        guardCaption: "Durante un momento tras cada cambio, UnTangle se asegura de que las teclas que escribes salgan en el nuevo idioma, aunque la app aún no se haya actualizado. Los atajos con ⌘ o ⌃ nunca se modifican. Mientras esta función esté instalada, los mismos ajustes se aplican cuando la tecla súper cambia la fuente de entrada.",
        strategyLabel: "Método",
        strategyRewrite: "Escribir la nueva letra (instantáneo)",
        strategyReplay: "Retener las teclas y enviarlas de nuevo",
        strategyCaption: "Escribir la nueva letra no añade retraso, pero solo funciona con distribuciones de teclado; al cambiar a un método de entrada, las teclas siempre se retienen. Retener funciona en todos los casos, pero retrasa esas teclas lo que dure la ventana de abajo.",
        windowLabel: "Ventana",
        millisecondsFormat: "%d ms",
        indicatorSection: "Indicador de idioma",
        indicatorToggle: "Mostrar el indicador de idioma de macOS junto al cursor",
        indicatorCaption: "macOS muestra la fuente de entrada junto al cursor de texto tras cada cambio. Desactivarlo puede hacer que el cambio se sienta más rápido. Es un ajuste de macOS: se aplica después de cerrar sesión y volver a entrar, y se mantiene aunque no uses UnTangle.",
        manageButton: "Configurar…"
    )

    static let sk = InstantInputSwitchStrings(
        pageTitle: "Okamžité prepínanie jazyka",
        hubDescription: "Prepne jazyk klávesnice okamžite a prvé písmená napísané hneď potom ponechá v novom jazyku.",
        enableToggle: "Prepínať zdroje vstupu cez UnTangle",
        enableCaption: "macOS zmení jazyk okamžite, ale aplikácie to zachytia neskôr, takže prvé písmená po prepnutí môžu vyjsť v starom jazyku. UnTangle prepína vlastným klávesom a tieto písmená opraví.",
        triggerLabel: "Prepínať",
        triggerControlSpace: "Control-medzerník",
        triggerFn: "Samostatným stlačením Fn (🌐)",
        triggerRightCommand: "Samostatným stlačením pravého ⌘",
        triggerRightOption: "Samostatným stlačením pravého ⌥",
        noteControlSpace: "Kým je táto funkcia zapnutá, UnTangle prevezme Control-medzerník od macOS a vráti ho, keď ju vypnete alebo keď je aktívne pole s heslom. Rovnako ako v macOS sa vráti na predchádzajúci jazyk; ostatné klávesy prepnú na ďalší v zozname.",
        noteFn: "Jazyk prepne iba krátke stlačenie 🌐 bez iného klávesu. Skratky s Fn fungujú naďalej.",
        noteModifier: "Jazyk prepne iba krátke stlačenie bez iného klávesu. Kláves naďalej funguje ako modifikátor.",
        fnUsageReady: "„Stlačenie klávesu 🌐“ („Stlačenie klávesu fn“) je nastavené na „Neurobí nič“, takže jazyk prepína iba UnTangle.",
        fnUsageChangesInputSource: "macOS prepína jazyk aj klávesom 🌐, takže by sa vrátil späť. V Systémových nastaveniach › Klávesnica nastavte „Stlačenie klávesu 🌐“ („Stlačenie klávesu fn“) na „Neurobí nič“.",
        fnUsageOther: "macOS používa 🌐 aj na emoji alebo diktovanie. V Systémových nastaveniach › Klávesnica nastavte „Stlačenie klávesu 🌐“ („Stlačenie klávesu fn“) na „Neurobí nič“, aby stlačenie iba prepínalo jazyk.",
        fnUsageUnknown: "UnTangle nevie zistiť, čo macOS robí pri klávese 🌐. Skontrolujte v Systémových nastaveniach › Klávesnica, či je „Stlačenie klávesu 🌐“ („Stlačenie klávesu fn“) nastavené na „Neurobí nič“.",
        openKeyboardSettings: "Otvoriť nastavenia klávesnice…",
        superKeyConflict: "Tento kláves používa super kláves, takže ho prepínanie nikdy nevidí. Vyberte iný kláves tu alebo pre super kláves.",
        activeNow: "Momentálne aktívne",
        guardSection: "Prvé písmená po prepnutí",
        guardToggle: "Ponechať prvé písmená v novom jazyku",
        guardCaption: "Chvíľu po každom prepnutí UnTangle zabezpečí, aby stlačené klávesy vyšli v novom jazyku, aj keď sa aplikácia ešte neprepla. Skratky s ⌘ alebo ⌃ sa nikdy nemenia. Kým je táto funkcia nainštalovaná, rovnaké nastavenia platia aj vtedy, keď zdroj vstupu prepína super kláves.",
        strategyLabel: "Spôsob",
        strategyRewrite: "Napísať nové písmeno (okamžite)",
        strategyReplay: "Podržať klávesy a poslať ich znova",
        strategyCaption: "Napísanie nového písmena nepridáva oneskorenie, ale funguje iba s rozloženiami klávesnice; pri prepnutí na metódu vstupu sa klávesy vždy podržia. Podržanie funguje všade, ale tieto klávesy oneskorí o okno nižšie.",
        windowLabel: "Okno",
        millisecondsFormat: "%d ms",
        indicatorSection: "Indikátor jazyka",
        indicatorToggle: "Zobrazovať indikátor jazyka macOS pri kurzore",
        indicatorCaption: "macOS po každom prepnutí zobrazí zdroj vstupu pri textovom kurzore. Ak ho vypnete, prepínanie môže pôsobiť rýchlejšie. Ide o nastavenie macOS: prejaví sa po odhlásení a opätovnom prihlásení a zostane tak aj bez UnTangle.",
        manageButton: "Nastaviť…"
    )

    static let de = InstantInputSwitchStrings(
        pageTitle: "Sofortiger Sprachwechsel",
        hubDescription: "Wechselt die Tastatursprache sofort und hält die ersten danach getippten Buchstaben in der neuen Sprache.",
        enableToggle: "Eingabequellen mit UnTangle wechseln",
        enableCaption: "macOS wechselt die Sprache sofort, aber Apps ziehen erst später nach, sodass die ersten Buchstaben nach einem Wechsel noch in der alten Sprache erscheinen können. UnTangle wechselt mit einer eigenen Taste und korrigiert diese Buchstaben.",
        triggerLabel: "Wechseln mit",
        triggerControlSpace: "Control-Leertaste",
        triggerFn: "Fn (🌐) allein gedrückt",
        triggerRightCommand: "Rechte ⌘ allein gedrückt",
        triggerRightOption: "Rechte ⌥ allein gedrückt",
        noteControlSpace: "Solange dies aktiv ist, übernimmt UnTangle Control-Leertaste von macOS und gibt sie zurück, wenn es aus ist oder ein Passwortfeld aktiv ist. Wie in macOS wechselt es zurück zur vorherigen Sprache; die anderen Tasten wechseln zur nächsten in der Liste.",
        noteFn: "Nur ein kurzes Drücken von 🌐 ohne andere Taste wechselt die Sprache. Kurzbefehle mit Fn funktionieren weiter.",
        noteModifier: "Nur ein kurzes Drücken ohne andere Taste wechselt die Sprache. Als Sondertaste funktioniert die Taste weiter.",
        fnUsageReady: "„Beim Drücken der 🌐-Taste“ („Beim Drücken der fn-Taste“) steht auf „Keine Aktion“, daher wechselt nur UnTangle die Sprache.",
        fnUsageChangesInputSource: "macOS wechselt die Sprache ebenfalls mit 🌐, sodass sie zurückspringen würde. Stelle in Systemeinstellungen › Tastatur „Beim Drücken der 🌐-Taste“ („Beim Drücken der fn-Taste“) auf „Keine Aktion“.",
        fnUsageOther: "macOS nutzt 🌐 auch für Emojis oder Diktieren. Stelle in Systemeinstellungen › Tastatur „Beim Drücken der 🌐-Taste“ („Beim Drücken der fn-Taste“) auf „Keine Aktion“, damit ein Drücken nur die Sprache wechselt.",
        fnUsageUnknown: "UnTangle kann nicht erkennen, was macOS bei 🌐 tut. Prüfe in Systemeinstellungen › Tastatur, ob „Beim Drücken der 🌐-Taste“ („Beim Drücken der fn-Taste“) auf „Keine Aktion“ steht.",
        openKeyboardSettings: "Tastatureinstellungen öffnen …",
        superKeyConflict: "Die Supertaste nutzt diese Taste, daher sieht der Wechsel sie nie. Wähle hier oder für die Supertaste eine andere Taste.",
        activeNow: "Läuft gerade",
        guardSection: "Erste Buchstaben nach einem Wechsel",
        guardToggle: "Erste Buchstaben in der neuen Sprache halten",
        guardCaption: "Kurz nach jedem Wechsel sorgt UnTangle dafür, dass getippte Tasten in der neuen Sprache erscheinen, auch wenn eine App noch nicht nachgezogen hat. Kurzbefehle mit ⌘ oder ⌃ bleiben unverändert. Solange diese Funktion installiert ist, gelten dieselben Einstellungen auch, wenn die Supertaste die Eingabequelle wechselt.",
        strategyLabel: "Methode",
        strategyRewrite: "Neuen Buchstaben tippen (sofort)",
        strategyReplay: "Tasten zurückhalten und erneut senden",
        strategyCaption: "Den neuen Buchstaben zu tippen verzögert nichts, funktioniert aber nur mit Tastaturbelegungen; beim Wechsel zu einer Eingabemethode werden die Tasten immer zurückgehalten. Zurückhalten funktioniert überall, verzögert diese Tasten aber um das Zeitfenster unten.",
        windowLabel: "Zeitfenster",
        millisecondsFormat: "%d ms",
        indicatorSection: "Sprachanzeige",
        indicatorToggle: "macOS-Sprachanzeige neben dem Cursor zeigen",
        indicatorCaption: "macOS zeigt nach jedem Wechsel die Eingabequelle neben dem Textcursor. Ist sie aus, kann sich der Wechsel schneller anfühlen. Dies ist eine macOS-Einstellung: Sie wirkt nach dem Ab- und erneuten Anmelden und bleibt auch ohne UnTangle bestehen.",
        manageButton: "Einrichten…"
    )

    static let fr = InstantInputSwitchStrings(
        pageTitle: "Changement de langue instantané",
        hubDescription: "Change la langue du clavier sur-le-champ et garde dans la nouvelle langue les premières lettres tapées juste après.",
        enableToggle: "Changer de source d’entrée avec UnTangle",
        enableCaption: "macOS change la langue sur-le-champ, mais les apps suivent plus tard, si bien que les premières lettres après un changement peuvent sortir dans l’ancienne langue. UnTangle change avec sa propre touche et corrige ces lettres.",
        triggerLabel: "Changer avec",
        triggerControlSpace: "Contrôle-Espace",
        triggerFn: "Fn (🌐) seule",
        triggerRightCommand: "⌘ droite seule",
        triggerRightOption: "⌥ droite seule",
        noteControlSpace: "Tant que cette option est active, UnTangle reprend Contrôle-Espace à macOS et le lui rend lorsqu’elle est désactivée ou qu’un champ de mot de passe est actif. Comme dans macOS, il revient à la langue précédente\u{00A0}; les autres touches passent à la suivante de la liste.",
        noteFn: "Seul un appui bref sur 🌐, sans autre touche, change la langue. Les raccourcis avec Fn fonctionnent toujours.",
        noteModifier: "Seul un appui bref, sans autre touche, change la langue. La touche fonctionne toujours comme touche de modification.",
        fnUsageReady: "«\u{00A0}Appuyer sur la touche 🌐 pour\u{00A0}» («\u{00A0}Appuyer sur la touche fn pour\u{00A0}») est réglé sur «\u{00A0}Ne rien faire\u{00A0}»\u{00A0}: seul UnTangle change la langue.",
        fnUsageChangesInputSource: "macOS change aussi la langue avec 🌐, qui reviendrait donc en arrière. Dans Réglages Système › Clavier, réglez «\u{00A0}Appuyer sur la touche 🌐 pour\u{00A0}» («\u{00A0}Appuyer sur la touche fn pour\u{00A0}») sur «\u{00A0}Ne rien faire\u{00A0}».",
        fnUsageOther: "macOS utilise aussi 🌐 pour les emoji ou la dictée. Dans Réglages Système › Clavier, réglez «\u{00A0}Appuyer sur la touche 🌐 pour\u{00A0}» («\u{00A0}Appuyer sur la touche fn pour\u{00A0}») sur «\u{00A0}Ne rien faire\u{00A0}» pour qu’un appui change seulement la langue.",
        fnUsageUnknown: "UnTangle ne peut pas savoir ce que macOS fait avec 🌐. Vérifiez dans Réglages Système › Clavier que «\u{00A0}Appuyer sur la touche 🌐 pour\u{00A0}» («\u{00A0}Appuyer sur la touche fn pour\u{00A0}») est réglé sur «\u{00A0}Ne rien faire\u{00A0}».",
        openKeyboardSettings: "Ouvrir les réglages du clavier…",
        superKeyConflict: "La touche super utilise cette touche, le changement ne la voit donc jamais. Choisissez une autre touche ici ou pour la touche super.",
        activeNow: "Actif maintenant",
        guardSection: "Premières lettres après un changement",
        guardToggle: "Garder les premières lettres dans la nouvelle langue",
        guardCaption: "Un court instant après chaque changement, UnTangle veille à ce que les touches tapées sortent dans la nouvelle langue, même dans une app qui n’a pas encore suivi. Les raccourcis avec ⌘ ou ⌃ ne sont jamais modifiés. Tant que cette fonction est installée, les mêmes réglages s’appliquent quand la touche super change la source d’entrée.",
        strategyLabel: "Méthode",
        strategyRewrite: "Taper la nouvelle lettre (instantané)",
        strategyReplay: "Retenir les touches et les renvoyer",
        strategyCaption: "Taper la nouvelle lettre n’ajoute aucun délai, mais ne fonctionne qu’avec les dispositions de clavier\u{00A0}; vers une méthode de saisie, les touches sont toujours retenues. Retenir fonctionne partout, mais retarde ces touches de la fenêtre ci-dessous.",
        windowLabel: "Fenêtre",
        millisecondsFormat: "%d\u{00A0}ms",
        indicatorSection: "Indicateur de langue",
        indicatorToggle: "Afficher l’indicateur de langue de macOS près du curseur",
        indicatorCaption: "macOS affiche la source d’entrée près du curseur de texte après chaque changement. Le désactiver peut rendre le changement plus vif. C’est un réglage de macOS\u{00A0}: il prend effet après une déconnexion puis une reconnexion, et reste ainsi même sans UnTangle.",
        manageButton: "Configurer…"
    )

    static let it = InstantInputSwitchStrings(
        pageTitle: "Cambio lingua istantaneo",
        hubDescription: "Cambia subito la lingua della tastiera e mantiene nella nuova lingua le prime lettere digitate subito dopo.",
        enableToggle: "Cambia sorgente di input con UnTangle",
        enableCaption: "macOS cambia subito la lingua, ma le app si adeguano più tardi, quindi le prime lettere dopo il cambio possono uscire nella lingua precedente. UnTangle cambia con un proprio tasto e corregge quelle lettere.",
        triggerLabel: "Cambia con",
        triggerControlSpace: "Control-Spazio",
        triggerFn: "Fn (🌐) premuto da solo",
        triggerRightCommand: "⌘ destro premuto da solo",
        triggerRightOption: "⌥ destro premuto da solo",
        noteControlSpace: "Finché è attivo, UnTangle prende Control-Spazio da macOS e lo restituisce quando viene disattivato o quando è attivo un campo password. Come in macOS, torna alla lingua precedente; gli altri tasti passano alla successiva nell’elenco.",
        noteFn: "Solo una pressione breve di 🌐 senza altri tasti cambia la lingua. Le abbreviazioni con Fn continuano a funzionare.",
        noteModifier: "Solo una pressione breve senza altri tasti cambia la lingua. Il tasto continua a funzionare come modificatore.",
        fnUsageReady: "“Premi il tasto 🌐 per” (“Premi il tasto Fn per”) è impostato su “Nessuna azione”, quindi solo UnTangle cambia la lingua.",
        fnUsageChangesInputSource: "Anche macOS cambia lingua con 🌐, quindi tornerebbe indietro. In Impostazioni di Sistema › Tastiera imposta “Premi il tasto 🌐 per” (“Premi il tasto Fn per”) su “Nessuna azione”.",
        fnUsageOther: "macOS usa 🌐 anche per emoji o dettatura. In Impostazioni di Sistema › Tastiera imposta “Premi il tasto 🌐 per” (“Premi il tasto Fn per”) su “Nessuna azione”, così una pressione cambia solo la lingua.",
        fnUsageUnknown: "UnTangle non riesce a capire cosa fa macOS con 🌐. Verifica in Impostazioni di Sistema › Tastiera che “Premi il tasto 🌐 per” (“Premi il tasto Fn per”) sia impostato su “Nessuna azione”.",
        openKeyboardSettings: "Apri impostazioni tastiera…",
        superKeyConflict: "Il tasto super usa questo tasto, quindi il cambio non lo vede mai. Scegli un altro tasto qui o per il tasto super.",
        activeNow: "Attivo ora",
        guardSection: "Prime lettere dopo il cambio",
        guardToggle: "Mantieni le prime lettere nella nuova lingua",
        guardCaption: "Per un attimo dopo ogni cambio, UnTangle fa sì che i tasti digitati escano nella nuova lingua, anche in un’app che non si è ancora adeguata. Le abbreviazioni con ⌘ o ⌃ non vengono mai toccate. Finché questa funzione è installata, le stesse impostazioni valgono quando il tasto super cambia la sorgente di input.",
        strategyLabel: "Metodo",
        strategyRewrite: "Digita la nuova lettera (istantaneo)",
        strategyReplay: "Trattieni i tasti e inviali di nuovo",
        strategyCaption: "Digitare la nuova lettera non aggiunge ritardo, ma funziona solo con i layout di tastiera; passando a un metodo di input i tasti vengono sempre trattenuti. Trattenere funziona ovunque, ma ritarda quei tasti della finestra qui sotto.",
        windowLabel: "Finestra",
        millisecondsFormat: "%d ms",
        indicatorSection: "Indicatore della lingua",
        indicatorToggle: "Mostra l’indicatore della lingua di macOS vicino al cursore",
        indicatorCaption: "macOS mostra la sorgente di input vicino al cursore di testo dopo ogni cambio. Disattivarlo può rendere il cambio più rapido. È un’impostazione di macOS: ha effetto dopo aver chiuso e riaperto la sessione e resta così anche senza UnTangle.",
        manageButton: "Configura…"
    )

    static let ja = InstantInputSwitchStrings(
        pageTitle: "即時入力切り替え",
        hubDescription: "キーボードの言語をすぐに切り替え、直後に入力した最初の文字も新しい言語で入力されるようにします。",
        enableToggle: "UnTangleで入力ソースを切り替える",
        enableCaption: "macOSは言語をすぐに切り替えますが、アプリが追いつくのは後になるため、切り替え直後の最初の文字が前の言語で入力されることがあります。UnTangleは専用のキーで切り替え、それらの文字を修正します。",
        triggerLabel: "切り替えキー",
        triggerControlSpace: "Control+スペース",
        triggerFn: "Fn（🌐）の単独押し",
        triggerRightCommand: "右⌘の単独押し",
        triggerRightOption: "右⌥の単独押し",
        noteControlSpace: "オンの間、UnTangleはmacOSからControl+スペースを引き継ぎ、オフにしたときやパスワード欄が選択されているときは元に戻します。macOSと同様に前の言語に戻ります。ほかのキーはリストの次の言語に切り替わります。",
        noteFn: "ほかのキーを押さずに🌐を短く押したときだけ切り替わります。Fnを使ったショートカットはそのまま使えます。",
        noteModifier: "ほかのキーを押さずに短く押したときだけ切り替わります。修飾キーとしてもそのまま使えます。",
        fnUsageReady: "「🌐キーを押して」（「fnキーを押して」）が「何もしない」に設定されているため、切り替えるのはUnTangleだけです。",
        fnUsageChangesInputSource: "macOSも🌐で言語を切り替えるため、元に戻ってしまいます。「システム設定 › キーボード」で「🌐キーを押して」（「fnキーを押して」）を「何もしない」に設定してください。",
        fnUsageOther: "macOSは🌐を絵文字や音声入力にも使っています。短く押したときに言語だけが切り替わるよう、「システム設定 › キーボード」で「🌐キーを押して」（「fnキーを押して」）を「何もしない」に設定してください。",
        fnUsageUnknown: "macOSが🌐で何をするかをUnTangleは判別できません。「システム設定 › キーボード」で「🌐キーを押して」（「fnキーを押して」）が「何もしない」になっているか確認してください。",
        openKeyboardSettings: "キーボード設定を開く…",
        superKeyConflict: "このキーはスーパーキーが使用しているため、切り替えに届きません。ここで、またはスーパーキー用に別のキーを選んでください。",
        activeNow: "動作中",
        guardSection: "切り替え直後の最初の文字",
        guardToggle: "最初の文字を新しい言語で入力する",
        guardCaption: "切り替えるたびに少しの間、アプリがまだ追いついていなくても、入力したキーが新しい言語で入力されるようにします。⌘や⌃を使ったショートカットは変更しません。この機能がインストールされている間は、スーパーキーで入力ソースを切り替えたときにも同じ設定が使われます。",
        strategyLabel: "方法",
        strategyRewrite: "新しい文字を入力（即時）",
        strategyReplay: "キーを保留して送り直す",
        strategyCaption: "新しい文字の入力は遅延がありませんが、キーボードレイアウトでのみ使えます。入力方式に切り替えた場合は常にキーを保留します。保留はどこでも使えますが、それらのキーが下の時間だけ遅れます。",
        windowLabel: "時間",
        millisecondsFormat: "%dミリ秒",
        indicatorSection: "言語インジケータ",
        indicatorToggle: "カーソルの横にmacOSの言語インジケータを表示",
        indicatorCaption: "macOSは切り替えるたびにテキストカーソルの横に入力ソースを表示します。オフにすると切り替えが速く感じられることがあります。これはmacOSの設定です。ログアウトして再ログインすると反映され、UnTangleがなくてもそのまま残ります。",
        manageButton: "設定…"
    )

    static let ko = InstantInputSwitchStrings(
        pageTitle: "즉시 입력 소스 전환",
        hubDescription: "키보드 언어를 바로 전환하고, 전환 직후 입력한 첫 글자도 새 언어로 입력되게 합니다.",
        enableToggle: "UnTangle로 입력 소스 전환",
        enableCaption: "macOS는 언어를 바로 바꾸지만 앱은 나중에 따라오기 때문에, 전환 직후 첫 글자가 이전 언어로 입력될 수 있습니다. UnTangle은 자체 키로 전환하고 그 글자들을 바로잡습니다.",
        triggerLabel: "전환 키",
        triggerControlSpace: "Control-스페이스",
        triggerFn: "Fn(🌐)만 눌러서",
        triggerRightCommand: "오른쪽 ⌘만 눌러서",
        triggerRightOption: "오른쪽 ⌥만 눌러서",
        noteControlSpace: "켜져 있는 동안 UnTangle이 macOS에서 Control-스페이스를 넘겨받고, 끄거나 암호 필드가 선택된 동안에는 다시 돌려줍니다. macOS처럼 이전 언어로 돌아가고, 다른 키는 목록의 다음 언어로 전환됩니다.",
        noteFn: "다른 키 없이 🌐를 짧게 눌렀을 때만 전환됩니다. Fn 단축키는 그대로 작동합니다.",
        noteModifier: "다른 키 없이 짧게 눌렀을 때만 전환됩니다. 보조 키로도 그대로 작동합니다.",
        fnUsageReady: "“🌐 키를 누를 때 실행할 동작”(“fn 키를 누를 때 실행할 동작”)이 “안 함”으로 설정되어 있어 UnTangle만 전환합니다.",
        fnUsageChangesInputSource: "macOS도 🌐로 언어를 전환하므로 원래대로 돌아갑니다. 시스템 설정 › 키보드에서 “🌐 키를 누를 때 실행할 동작”(“fn 키를 누를 때 실행할 동작”)을 “안 함”으로 설정하십시오.",
        fnUsageOther: "macOS가 🌐를 이모티콘이나 받아쓰기에도 사용합니다. 짧게 누를 때 언어만 전환되도록 시스템 설정 › 키보드에서 “🌐 키를 누를 때 실행할 동작”(“fn 키를 누를 때 실행할 동작”)을 “안 함”으로 설정하십시오.",
        fnUsageUnknown: "UnTangle은 macOS가 🌐로 무엇을 하는지 알 수 없습니다. 시스템 설정 › 키보드에서 “🌐 키를 누를 때 실행할 동작”(“fn 키를 누를 때 실행할 동작”)이 “안 함”인지 확인하십시오.",
        openKeyboardSettings: "키보드 설정 열기…",
        superKeyConflict: "슈퍼 키가 이 키를 사용하므로 전환에 전달되지 않습니다. 여기서 또는 슈퍼 키에 다른 키를 선택하십시오.",
        activeNow: "지금 작동 중",
        guardSection: "전환 직후의 첫 글자",
        guardToggle: "첫 글자를 새 언어로 유지",
        guardCaption: "전환할 때마다 잠시 동안, 앱이 아직 따라오지 못했더라도 입력한 키가 새 언어로 입력되도록 합니다. ⌘ 또는 ⌃ 단축키는 건드리지 않습니다. 이 기능이 설치되어 있는 동안에는 슈퍼 키로 입력 소스를 전환할 때도 같은 설정이 적용됩니다.",
        strategyLabel: "방식",
        strategyRewrite: "새 글자로 입력(즉시)",
        strategyReplay: "키를 붙잡았다가 다시 보내기",
        strategyCaption: "새 글자로 입력하면 지연이 없지만 키보드 레이아웃에서만 작동합니다. 입력기로 전환할 때는 항상 키를 붙잡습니다. 붙잡기는 어디서나 작동하지만 해당 키가 아래 시간만큼 늦어집니다.",
        windowLabel: "시간",
        millisecondsFormat: "%dms",
        indicatorSection: "언어 표시기",
        indicatorToggle: "커서 옆에 macOS 언어 표시기 보기",
        indicatorCaption: "macOS는 전환할 때마다 텍스트 커서 옆에 입력 소스를 표시합니다. 끄면 전환이 더 빠르게 느껴질 수 있습니다. 이는 macOS 설정으로, 로그아웃 후 다시 로그인하면 적용되며 UnTangle이 없어도 그대로 유지됩니다.",
        manageButton: "설정…"
    )

    static let uk = InstantInputSwitchStrings(
        pageTitle: "Миттєве перемикання мови",
        hubDescription: "Перемикає мову клавіатури одразу й зберігає перші літери після перемикання в новій мові.",
        enableToggle: "Перемикати джерела вводу через UnTangle",
        enableCaption: "macOS змінює мову одразу, але програми підхоплюють її пізніше, тож перші літери після перемикання можуть вийти старою мовою. UnTangle перемикає власною клавішею і виправляє ці літери.",
        triggerLabel: "Перемикати",
        triggerControlSpace: "Control-Пробіл",
        triggerFn: "Окремим натисканням Fn (🌐)",
        triggerRightCommand: "Окремим натисканням правого ⌘",
        triggerRightOption: "Окремим натисканням правого ⌥",
        noteControlSpace: "Поки функція увімкнена, UnTangle забирає Control-Пробіл у macOS і повертає його, коли функцію вимкнено або коли активне поле пароля. Як і в macOS, він повертає попередню мову; інші клавіші перемикають на наступну у списку.",
        noteFn: "Перемикає лише коротке натискання 🌐 без інших клавіш. Сполучення з Fn працюють як і раніше.",
        noteModifier: "Перемикає лише коротке натискання без інших клавіш. Як модифікатор клавіша працює як і раніше.",
        fnUsageReady: "«Натискати клавішу 🌐, щоб» («Натискати клавішу fn, щоб») встановлено на «нічого не робити», тож мову перемикає лише UnTangle.",
        fnUsageChangesInputSource: "macOS теж перемикає мову по 🌐, і вона повернеться назад. У «Системні параметри › Клавіатура» встановіть «Натискати клавішу 🌐, щоб» («Натискати клавішу fn, щоб») на «нічого не робити».",
        fnUsageOther: "macOS також використовує 🌐 для емодзі або диктування. У «Системні параметри › Клавіатура» встановіть «Натискати клавішу 🌐, щоб» («Натискати клавішу fn, щоб») на «нічого не робити», щоб натискання лише перемикало мову.",
        fnUsageUnknown: "UnTangle не може визначити, що macOS робить по 🌐. Перевірте, що в «Системні параметри › Клавіатура» для «Натискати клавішу 🌐, щоб» («Натискати клавішу fn, щоб») вибрано «нічого не робити».",
        openKeyboardSettings: "Відкрити параметри клавіатури…",
        superKeyConflict: "Цю клавішу використовує Супер-клавіша, тому перемикання її не бачить. Виберіть іншу клавішу тут або для Супер-клавіші.",
        activeNow: "Зараз працює",
        guardSection: "Перші літери після перемикання",
        guardToggle: "Зберігати перші літери в новій мові",
        guardCaption: "Протягом короткого часу після кожного перемикання UnTangle стежить, щоб натиснуті клавіші виходили новою мовою, навіть якщо програма ще не встигла перемкнутися. Сполучення з ⌘ або ⌃ не змінюються. Поки цю функцію встановлено, ці ж налаштування діють, коли мову перемикає Супер-клавіша.",
        strategyLabel: "Спосіб",
        strategyRewrite: "Підставляти нову літеру (миттєво)",
        strategyReplay: "Затримувати клавіші й надсилати повторно",
        strategyCaption: "Підстановка не додає затримки, але працює лише з розкладками; при перемиканні на метод введення клавіші завжди затримуються. Затримка працює всюди, але відкладає ці клавіші на вікно нижче.",
        windowLabel: "Вікно",
        millisecondsFormat: "%d мс",
        indicatorSection: "Індикатор мови",
        indicatorToggle: "Показувати індикатор мови macOS біля курсора",
        indicatorCaption: "Після кожного перемикання macOS показує джерело вводу біля текстового курсора. Якщо його вимкнути, перемикання може відчуватися швидшим. Це налаштування macOS: воно діє після виходу із системи й повторного входу та лишається таким навіть без UnTangle.",
        manageButton: "Налаштувати…"
    )

    static let zhHans = InstantInputSwitchStrings(
        pageTitle: "即时切换输入法",
        hubDescription: "立即切换键盘语言，并让切换后紧接着输入的头几个字母也使用新语言。",
        enableToggle: "用 UnTangle 切换输入法",
        enableCaption: "macOS 会立即切换语言，但应用要稍后才跟上，因此切换后的头几个字母可能仍以旧语言输入。UnTangle 用自己的按键切换，并修正这些字母。",
        triggerLabel: "切换方式",
        triggerControlSpace: "Control-空格键",
        triggerFn: "单独按 Fn（🌐）",
        triggerRightCommand: "单独按右侧 ⌘",
        triggerRightOption: "单独按右侧 ⌥",
        noteControlSpace: "开启期间，UnTangle 会从 macOS 接管 Control-空格键，关闭时或聚焦密码栏时再交还。与 macOS 一样，它会回到上一个语言；其他按键会切换到列表中的下一个。",
        noteFn: "只有不按其他键、短按 🌐 才会切换。使用 Fn 的快捷键照常可用。",
        noteModifier: "只有不按其他键、短按时才会切换。该键作为修饰键照常可用。",
        fnUsageReady: "“按下🌐键时”（“按下fn键时”）已设为“不执行任何操作”，因此只有 UnTangle 会切换语言。",
        fnUsageChangesInputSource: "macOS 也会在按 🌐 时切换语言，结果会切回原来的语言。请在“系统设置 › 键盘”中将“按下🌐键时”（“按下fn键时”）设为“不执行任何操作”。",
        fnUsageOther: "macOS 还会把 🌐 用于表情符号或听写。请在“系统设置 › 键盘”中将“按下🌐键时”（“按下fn键时”）设为“不执行任何操作”，让短按只切换语言。",
        fnUsageUnknown: "UnTangle 无法判断 macOS 在按 🌐 时会做什么。请在“系统设置 › 键盘”中确认“按下🌐键时”（“按下fn键时”）已设为“不执行任何操作”。",
        openKeyboardSettings: "打开键盘设置…",
        superKeyConflict: "超级键正在使用此键，因此切换功能收不到它。请在此处或为超级键选择其他按键。",
        activeNow: "正在运行",
        guardSection: "切换后的头几个字母",
        guardToggle: "让头几个字母使用新语言",
        guardCaption: "每次切换后的短时间内，即使应用尚未跟上，UnTangle 也会确保你输入的按键以新语言输出。带 ⌘ 或 ⌃ 的快捷键不会被改动。安装此功能期间，用超级键切换输入法时也使用相同设置。",
        strategyLabel: "方式",
        strategyRewrite: "输入新字母（即时）",
        strategyReplay: "暂留按键并重新发送",
        strategyCaption: "输入新字母不会增加延迟，但只适用于键盘布局；切换到输入法时总会暂留按键。暂留在任何情况下都可用，但会让这些按键延迟下方的时长。",
        windowLabel: "时长",
        millisecondsFormat: "%d 毫秒",
        indicatorSection: "语言指示器",
        indicatorToggle: "在光标旁显示 macOS 语言指示器",
        indicatorCaption: "每次切换后，macOS 都会在文本光标旁显示输入法。关闭后切换可能感觉更快。这是 macOS 设置：注销并重新登录后生效，即使没有 UnTangle 也会保持。",
        manageButton: "设置…"
    )

    static let zhTW = InstantInputSwitchStrings(
        pageTitle: "即時切換輸入法",
        hubDescription: "立即切換鍵盤語言，並讓切換後緊接著輸入的前幾個字母也使用新語言。",
        enableToggle: "使用 UnTangle 切換輸入法",
        enableCaption: "macOS 會立即切換語言，但 App 要稍後才會跟上，因此切換後的前幾個字母可能仍以舊語言輸入。UnTangle 以自己的按鍵切換，並修正這些字母。",
        triggerLabel: "切換方式",
        triggerControlSpace: "Control-空白鍵",
        triggerFn: "單獨按 Fn（🌐）",
        triggerRightCommand: "單獨按右側 ⌘",
        triggerRightOption: "單獨按右側 ⌥",
        noteControlSpace: "開啟期間，UnTangle 會從 macOS 接管 Control-空白鍵，關閉時或密碼欄位為焦點時再交還。與 macOS 相同，它會回到上一個語言；其他按鍵會切換到列表中的下一個。",
        noteFn: "只有不按其他鍵、短按 🌐 才會切換。使用 Fn 的快速鍵照常可用。",
        noteModifier: "只有不按其他鍵、短按時才會切換。此鍵作為輔助鍵照常可用。",
        fnUsageReady: "「按下🌐鍵來」（「按下fn鍵來」）已設為「不執行任何動作」，因此只有 UnTangle 會切換語言。",
        fnUsageChangesInputSource: "macOS 也會在按 🌐 時切換語言，結果會切回原本的語言。請在「系統設定 › 鍵盤」中將「按下🌐鍵來」（「按下fn鍵來」）設為「不執行任何動作」。",
        fnUsageOther: "macOS 也會將 🌐 用於表情符號或聽寫。請在「系統設定 › 鍵盤」中將「按下🌐鍵來」（「按下fn鍵來」）設為「不執行任何動作」，讓短按只切換語言。",
        fnUsageUnknown: "UnTangle 無法判斷 macOS 在按 🌐 時會做什麼。請在「系統設定 › 鍵盤」中確認「按下🌐鍵來」（「按下fn鍵來」）已設為「不執行任何動作」。",
        openKeyboardSettings: "打開鍵盤設定…",
        superKeyConflict: "超級鍵正在使用此鍵，因此切換功能收不到它。請在這裡或為超級鍵選擇其他按鍵。",
        activeNow: "正在運作",
        guardSection: "切換後的前幾個字母",
        guardToggle: "讓前幾個字母使用新語言",
        guardCaption: "每次切換後的短時間內，即使 App 尚未跟上，UnTangle 也會確保你輸入的按鍵以新語言輸出。含 ⌘ 或 ⌃ 的快速鍵不會被更動。安裝此功能期間，以超級鍵切換輸入法時也使用相同設定。",
        strategyLabel: "方式",
        strategyRewrite: "輸入新字母（即時）",
        strategyReplay: "暫留按鍵並重新傳送",
        strategyCaption: "輸入新字母不會增加延遲，但只適用於鍵盤配置；切換到輸入法時一律會暫留按鍵。暫留在任何情況下都可用，但會讓這些按鍵延遲下方的時間長度。",
        windowLabel: "時間長度",
        millisecondsFormat: "%d 毫秒",
        indicatorSection: "語言指示器",
        indicatorToggle: "在游標旁顯示 macOS 語言指示器",
        indicatorCaption: "每次切換後，macOS 都會在文字游標旁顯示輸入法。關閉後切換可能感覺更快。這是 macOS 設定：登出並重新登入後生效，即使沒有 UnTangle 也會保持。",
        manageButton: "設定…"
    )

    static let zhHK = InstantInputSwitchStrings(
        pageTitle: "即時切換輸入法",
        hubDescription: "即時切換鍵盤語言，並令切換後緊接輸入的頭幾個字母都用新語言。",
        enableToggle: "用 UnTangle 切換輸入法",
        enableCaption: "macOS 會即時切換語言，但 App 要遲啲先跟上，所以切換後頭幾個字母可能仍然用舊語言輸入。UnTangle 用自己嘅按鍵切換，並修正呢啲字母。",
        triggerLabel: "切換方式",
        triggerControlSpace: "Control-空白鍵",
        triggerFn: "單獨撳 Fn（🌐）",
        triggerRightCommand: "單獨撳右邊 ⌘",
        triggerRightOption: "單獨撳右邊 ⌥",
        noteControlSpace: "開啟期間，UnTangle 會從 macOS 接管 Control-空白鍵，關閉時或密碼欄位為焦點時再交還。同 macOS 一樣，佢會返去上一個語言；其他按鍵會切換到列表中嘅下一個。",
        noteFn: "只有唔撳其他鍵、短撳 🌐 先會切換。用 Fn 嘅快速鍵照常可用。",
        noteModifier: "只有唔撳其他鍵、短撳時先會切換。呢個鍵作為輔助鍵照常可用。",
        fnUsageReady: "「按🌐鍵來」（「按fn鍵來」）已設為「不執行任何操作」，所以只有 UnTangle 會切換語言。",
        fnUsageChangesInputSource: "macOS 都會喺撳 🌐 時切換語言，結果會切返原本嘅語言。請喺「系統設定 › 鍵盤」將「按🌐鍵來」（「按fn鍵來」）設為「不執行任何操作」。",
        fnUsageOther: "macOS 亦會將 🌐 用於表情符號或聽寫。請喺「系統設定 › 鍵盤」將「按🌐鍵來」（「按fn鍵來」）設為「不執行任何操作」，令短撳只切換語言。",
        fnUsageUnknown: "UnTangle 無法判斷 macOS 撳 🌐 時會做乜。請喺「系統設定 › 鍵盤」確認「按🌐鍵來」（「按fn鍵來」）已設為「不執行任何操作」。",
        openKeyboardSettings: "打開鍵盤設定…",
        superKeyConflict: "超級鍵正在使用呢個鍵，所以切換功能收唔到佢。請喺度或者為超級鍵揀其他按鍵。",
        activeNow: "正在運作",
        guardSection: "切換後頭幾個字母",
        guardToggle: "令頭幾個字母用新語言",
        guardCaption: "每次切換後嘅短時間內，就算 App 未跟上，UnTangle 都會確保你輸入嘅按鍵用新語言輸出。有 ⌘ 或 ⌃ 嘅快速鍵唔會被改動。安裝咗呢個功能期間，用超級鍵切換輸入法時都會用相同設定。",
        strategyLabel: "方式",
        strategyRewrite: "輸入新字母（即時）",
        strategyReplay: "暫留按鍵再重新傳送",
        strategyCaption: "輸入新字母唔會增加延遲，但只適用於鍵盤配置；切換到輸入法時一律會暫留按鍵。暫留喺任何情況都用得，但會令呢啲按鍵延遲下面嘅時間長度。",
        windowLabel: "時間長度",
        millisecondsFormat: "%d 毫秒",
        indicatorSection: "語言指示器",
        indicatorToggle: "喺游標旁邊顯示 macOS 語言指示器",
        indicatorCaption: "每次切換後，macOS 都會喺文字游標旁邊顯示輸入法。關咗之後切換可能會覺得快啲。呢個係 macOS 設定：登出再登入後先生效，就算冇 UnTangle 都會保持。",
        manageButton: "設定…"
    )
}
