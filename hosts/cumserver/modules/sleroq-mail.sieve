require ["fileinto", "mailbox", "regex", "comparator-i;unicode-casemap"];

# Leave marked spam for the server's Junk rule.
if header :is "X-Spam" "Yes" {
    keep;
}

# Account access takes precedence over sender-based filing and list headers.
elsif anyof (
    header :contains "Subject" [
        "verification code", "authentication code", "security code", "confirmation code",
        "login code", "log in code", "sign-in code", "sign in code", "signin code",
        "one-time code", "one-time password", "one-time verification", "one-time passcode",
        "magic link login", "password reset", "reset your password", "password change",
        "password was changed", "password has been changed", "security alert", "security notification",
        "unusual sign-in", "new sign-in", "new login", "login from a new device",
        "login attempt", "log in attempt", "approve sign-in", "potential security breach",
        "otp for logging in", "one-time pin", "single-use code",
        "verify your email", "verify email", "email verification", "e-mail verification",
        "verification of your email address", "account verification", "confirm your email",
        "confirm new email address", "new account confirmation", "account details confirmation",
        "authentication to your account creation", "to complete your account setup",
        "verify email for your", "confirm your new account",
        "your chatgpt code", "your openai code", "oauth application has been added to your account",
        "public key was added to your account", "personal access token (classic) is about to expire",
        "multi-factor authentication settings", "account recovery",
        "password changed", "password updated", "two factor authentication", "two-factor authentication",
        "new device signed in", "security update: action required"
    ],
    header :regex "Subject" [
        "(^|[^[:alnum:]])(OTP|PIN)[ -]?code([^[:alnum:]]|$)",
        "(^|[^[:alnum:]])(your code[ :−–-]|sign in to |log in to |login for |your one-time |verify your .*account|confirm your .*account|use [[:digit:]]+ to login)",
        "(two[ -]factor|multi[ -]factor|2FA|MFA|2SV).*(authentication|code|settings|recovery)"
    ],
    header :comparator "i;unicode-casemap" :contains "Subject" [
        "код входа", "код для входа", "код подтверждения", "код безопасности",
        "код авторизации", "одноразовый код", "код  для аутентификации",
        "код для аутентификации", "попытка входа", "новый вход", "сброс пароля",
        "восстановление пароля", "изменение пароля", "подтверждение почты",
        "подтверждение адреса электронной почты", "подтверждение e-mail",
        "подтверждение регистрации"
    ]
) {
    fileinto :create "Auth";
}

# File receipts, invoices, and billing notices by transactional subjects or receipt senders,
# not incidental words in newsletter bodies. A real receipt can have unsubscribe headers.
elsif anyof (
    header :regex "Subject" [
        "(^|[^[:alnum:]])(your receipt|payment receipt|order receipt|tax receipt|receipt from|invoice #[[:digit:]]|invoice of [[:digit:]]|invoice overdue|customer invoice|invoice payment|payment confirmation|payment received|order confirmation)([^[:alnum:]]|$)",
        "^(receipt|invoice|tax invoice|your invoice)([ :#]|$)",
        "(paid your invoice|services auto-renewal confirmation|introduction of VAT on your invoices)"
    ],
    header :comparator "i;unicode-casemap" :contains "Subject" [
        "кассовый чек", "электронный чек", "онлайн-чек", "ваш чек", "подарок к чеку",
        "чек от http", "чек на ", "чек +", "оплата подтверждена", "оплата услуг",
        "ваша покупка на площадке", "квитанция с билетами по заказу"
    ],
    header :comparator "i;unicode-casemap" :matches "Subject" ["чек *", "чек: *"],
    address :domain :is "From" ["chek.pofd.ru", "1-ofd.ru", "ofd.ru"],
    address :localpart :matches "From" ["receipts", "receipt", "receipts+*", "invoice+statements*", "noreply-cloudkassir"]
) {
    fileinto :create "Purchases";
}

# Mixed bank senders also send receipts and account notices; match their offer subjects only.
elsif anyof (
    address :domain :is "From" ["news.ozon.ru", "ozon.travel"],
    address :is "From" [
        "bringafriend@emails.tinkoff.ru", "offers@emails.tinkoff.ru", "card@mail.5ka.ru"
    ],
    allof (
        address :is "From" [
            "credit@emails.tinkoff.ru", "deposit@emails.tinkoff.ru",
            "inform@emails.tinkoff.ru", "email@send.vtb.ru"
        ],
        header :comparator "i;unicode-casemap" :contains "Subject" [
            "одобрили кредитную карту", "одобрена кредитная карта", "кредит наличными одобрен",
            "бесплатная кредитка", "автокредит от втб", "если нужны деньги",
            "приглашайте друзей", "за рекомендацию зарплатной карты", "спецпредложени",
            "выиграйте", "шанс выиграть", "розыгрыш", "призоград", "разыгрываем",
            "скидк", "распродажа", "промокод", "большим кэшбэком", "кэшбэк до",
            "вклад со ставкой", "откройте вклад под", "% по втб-вкладу",
            "% годовых —", "% годовых на", "% годовых уже", "знания — деньги"
        ]
    )
) {
    fileinto :create "Ads";
}
elsif address :domain :matches "From" ["linkedin.com", "*.linkedin.com", "match.indeed.com"] {
    fileinto :create "Job";
}

# Known subscription senders also send mail without mailing-list headers.
elsif anyof (
    address :domain :matches "From" [
        "openai.com", "*.openai.com", "myrobot.com", "*.myrobot.com",
        "coinbureau.com", "*.coinbureau.com", "locals.com", "*.locals.com"
    ],
    exists "List-Unsubscribe"
) {
    fileinto :create "Subscriptions";
}
