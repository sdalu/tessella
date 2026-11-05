# frozen_string_literal: true

module Tessella
    # Each text style as { from:, to: }: the plain characters it has a
    # form for, and those forms, in the same order -- generated from
    # Unicode 16's names and decompositions (<font>, <super>, <sub>,
    # <circle>, <wide>, <square>), never by code point offsets. The
    # Mathematical Alphanumeric holes are filled from Letterlike
    # Symbols (ℎ ℬ ℰ ℱ ℋ ℐ ℒ ℳ ℛ ℯ ℊ ℴ ℭ ℌ ℑ ℜ ℨ ℂ ℍ ℕ ℙ ℚ ℝ ℤ); the
    # ordinal indicators (ª º) are not superscripts.
    module Text
        # The Mathematical Alphanumeric Symbols styles.
        module MathForms
            FORMS = {
                bold: {
                    from: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcd" \
                          "efghijklmnopqrstuvwxyz",
                    to: "𝟎𝟏𝟐𝟑𝟒𝟓𝟔𝟕𝟖𝟗𝐀𝐁𝐂𝐃𝐄𝐅𝐆𝐇𝐈𝐉𝐊𝐋𝐌𝐍𝐎𝐏𝐐𝐑𝐒𝐓𝐔𝐕𝐖𝐗𝐘𝐙𝐚𝐛𝐜𝐝" \
                        "𝐞𝐟𝐠𝐡𝐢𝐣𝐤𝐥𝐦𝐧𝐨𝐩𝐪𝐫𝐬𝐭𝐮𝐯𝐰𝐱𝐲𝐳"
                },
                italic: {
                    from: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn" \
                          "opqrstuvwxyz",
                    to: "𝐴𝐵𝐶𝐷𝐸𝐹𝐺𝐻𝐼𝐽𝐾𝐿𝑀𝑁𝑂𝑃𝑄𝑅𝑆𝑇𝑈𝑉𝑊𝑋𝑌𝑍𝑎𝑏𝑐𝑑𝑒𝑓𝑔ℎ𝑖𝑗𝑘𝑙𝑚𝑛" \
                        "𝑜𝑝𝑞𝑟𝑠𝑡𝑢𝑣𝑤𝑥𝑦𝑧"
                },
                bold_italic: {
                    from: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn" \
                          "opqrstuvwxyz",
                    to: "𝑨𝑩𝑪𝑫𝑬𝑭𝑮𝑯𝑰𝑱𝑲𝑳𝑴𝑵𝑶𝑷𝑸𝑹𝑺𝑻𝑼𝑽𝑾𝑿𝒀𝒁𝒂𝒃𝒄𝒅𝒆𝒇𝒈𝒉𝒊𝒋𝒌𝒍𝒎𝒏" \
                        "𝒐𝒑𝒒𝒓𝒔𝒕𝒖𝒗𝒘𝒙𝒚𝒛"
                },
                script: {
                    from: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn" \
                          "opqrstuvwxyz",
                    to: "𝒜ℬ𝒞𝒟ℰℱ𝒢ℋℐ𝒥𝒦ℒℳ𝒩𝒪𝒫𝒬ℛ𝒮𝒯𝒰𝒱𝒲𝒳𝒴𝒵𝒶𝒷𝒸𝒹ℯ𝒻ℊ𝒽𝒾𝒿𝓀𝓁𝓂𝓃" \
                        "ℴ𝓅𝓆𝓇𝓈𝓉𝓊𝓋𝓌𝓍𝓎𝓏"
                },
                bold_script: {
                    from: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn" \
                          "opqrstuvwxyz",
                    to: "𝓐𝓑𝓒𝓓𝓔𝓕𝓖𝓗𝓘𝓙𝓚𝓛𝓜𝓝𝓞𝓟𝓠𝓡𝓢𝓣𝓤𝓥𝓦𝓧𝓨𝓩𝓪𝓫𝓬𝓭𝓮𝓯𝓰𝓱𝓲𝓳𝓴𝓵𝓶𝓷" \
                        "𝓸𝓹𝓺𝓻𝓼𝓽𝓾𝓿𝔀𝔁𝔂𝔃"
                },
                fraktur: {
                    from: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn" \
                          "opqrstuvwxyz",
                    to: "𝔄𝔅ℭ𝔇𝔈𝔉𝔊ℌℑ𝔍𝔎𝔏𝔐𝔑𝔒𝔓𝔔ℜ𝔖𝔗𝔘𝔙𝔚𝔛𝔜ℨ𝔞𝔟𝔠𝔡𝔢𝔣𝔤𝔥𝔦𝔧𝔨𝔩𝔪𝔫" \
                        "𝔬𝔭𝔮𝔯𝔰𝔱𝔲𝔳𝔴𝔵𝔶𝔷"
                },
                bold_fraktur: {
                    from: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn" \
                          "opqrstuvwxyz",
                    to: "𝕬𝕭𝕮𝕯𝕰𝕱𝕲𝕳𝕴𝕵𝕶𝕷𝕸𝕹𝕺𝕻𝕼𝕽𝕾𝕿𝖀𝖁𝖂𝖃𝖄𝖅𝖆𝖇𝖈𝖉𝖊𝖋𝖌𝖍𝖎𝖏𝖐𝖑𝖒𝖓" \
                        "𝖔𝖕𝖖𝖗𝖘𝖙𝖚𝖛𝖜𝖝𝖞𝖟"
                },
                double_struck: {
                    from: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcd" \
                          "efghijklmnopqrstuvwxyz",
                    to: "𝟘𝟙𝟚𝟛𝟜𝟝𝟞𝟟𝟠𝟡𝔸𝔹ℂ𝔻𝔼𝔽𝔾ℍ𝕀𝕁𝕂𝕃𝕄ℕ𝕆ℙℚℝ𝕊𝕋𝕌𝕍𝕎𝕏𝕐ℤ𝕒𝕓𝕔𝕕" \
                        "𝕖𝕗𝕘𝕙𝕚𝕛𝕜𝕝𝕞𝕟𝕠𝕡𝕢𝕣𝕤𝕥𝕦𝕧𝕨𝕩𝕪𝕫"
                },
                sans: {
                    from: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcd" \
                          "efghijklmnopqrstuvwxyz",
                    to: "𝟢𝟣𝟤𝟥𝟦𝟧𝟨𝟩𝟪𝟫𝖠𝖡𝖢𝖣𝖤𝖥𝖦𝖧𝖨𝖩𝖪𝖫𝖬𝖭𝖮𝖯𝖰𝖱𝖲𝖳𝖴𝖵𝖶𝖷𝖸𝖹𝖺𝖻𝖼𝖽" \
                        "𝖾𝖿𝗀𝗁𝗂𝗃𝗄𝗅𝗆𝗇𝗈𝗉𝗊𝗋𝗌𝗍𝗎𝗏𝗐𝗑𝗒𝗓"
                },
                sans_bold: {
                    from: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcd" \
                          "efghijklmnopqrstuvwxyz",
                    to: "𝟬𝟭𝟮𝟯𝟰𝟱𝟲𝟳𝟴𝟵𝗔𝗕𝗖𝗗𝗘𝗙𝗚𝗛𝗜𝗝𝗞𝗟𝗠𝗡𝗢𝗣𝗤𝗥𝗦𝗧𝗨𝗩𝗪𝗫𝗬𝗭𝗮𝗯𝗰𝗱" \
                        "𝗲𝗳𝗴𝗵𝗶𝗷𝗸𝗹𝗺𝗻𝗼𝗽𝗾𝗿𝘀𝘁𝘂𝘃𝘄𝘅𝘆𝘇"
                },
                sans_italic: {
                    from: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn" \
                          "opqrstuvwxyz",
                    to: "𝘈𝘉𝘊𝘋𝘌𝘍𝘎𝘏𝘐𝘑𝘒𝘓𝘔𝘕𝘖𝘗𝘘𝘙𝘚𝘛𝘜𝘝𝘞𝘟𝘠𝘡𝘢𝘣𝘤𝘥𝘦𝘧𝘨𝘩𝘪𝘫𝘬𝘭𝘮𝘯" \
                        "𝘰𝘱𝘲𝘳𝘴𝘵𝘶𝘷𝘸𝘹𝘺𝘻"
                },
                sans_bold_italic: {
                    from: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn" \
                          "opqrstuvwxyz",
                    to: "𝘼𝘽𝘾𝘿𝙀𝙁𝙂𝙃𝙄𝙅𝙆𝙇𝙈𝙉𝙊𝙋𝙌𝙍𝙎𝙏𝙐𝙑𝙒𝙓𝙔𝙕𝙖𝙗𝙘𝙙𝙚𝙛𝙜𝙝𝙞𝙟𝙠𝙡𝙢𝙣" \
                        "𝙤𝙥𝙦𝙧𝙨𝙩𝙪𝙫𝙬𝙭𝙮𝙯"
                },
                monospace: {
                    from: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcd" \
                          "efghijklmnopqrstuvwxyz",
                    to: "𝟶𝟷𝟸𝟹𝟺𝟻𝟼𝟽𝟾𝟿𝙰𝙱𝙲𝙳𝙴𝙵𝙶𝙷𝙸𝙹𝙺𝙻𝙼𝙽𝙾𝙿𝚀𝚁𝚂𝚃𝚄𝚅𝚆𝚇𝚈𝚉𝚊𝚋𝚌𝚍" \
                        "𝚎𝚏𝚐𝚑𝚒𝚓𝚔𝚕𝚖𝚗𝚘𝚙𝚚𝚛𝚜𝚝𝚞𝚟𝚠𝚡𝚢𝚣"
                }
            }.freeze
        end

        # Small caps, super/subscripts, enclosed and fullwidth forms.
        module OtherForms
            FORMS = {
                small_caps: {
                    from: "abcdefghijklmnopqrstuvwyz",
                    to: "ᴀʙᴄᴅᴇꜰɢʜɪᴊᴋʟᴍɴᴏᴘꞯʀꜱᴛᴜᴠᴡʏᴢ"
                },
                superscript: {
                    from: "0123456789ABCDEFGHIJKLMNOPQRTUVWabcdefgh" \
                          "ijklmnopqrstuvwxyz",
                    to: "⁰¹²³⁴⁵⁶⁷⁸⁹ᴬᴮꟲᴰᴱꟳᴳᴴᴵᴶᴷᴸᴹᴺᴼᴾꟴᴿᵀᵁⱽᵂᵃᵇᶜᵈᵉᶠᵍʰ" \
                        "ⁱʲᵏˡᵐⁿᵒᵖ𐞥ʳˢᵗᵘᵛʷˣʸᶻ"
                },
                subscript: {
                    from: "0123456789aehijklmnoprstuvx",
                    to: "₀₁₂₃₄₅₆₇₈₉ₐₑₕᵢⱼₖₗₘₙₒₚᵣₛₜᵤᵥₓ"
                },
                circled: {
                    from: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcd" \
                          "efghijklmnopqrstuvwxyz",
                    to: "⓪①②③④⑤⑥⑦⑧⑨ⒶⒷⒸⒹⒺⒻⒼⒽⒾⒿⓀⓁⓂⓃⓄⓅⓆⓇⓈⓉⓊⓋⓌⓍⓎⓏⓐⓑⓒⓓ" \
                        "ⓔⓕⓖⓗⓘⓙⓚⓛⓜⓝⓞⓟⓠⓡⓢⓣⓤⓥⓦⓧⓨⓩ"
                },
                negative_circled: {
                    from: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ",
                    to: "⓿❶❷❸❹❺❻❼❽❾🅐🅑🅒🅓🅔🅕🅖🅗🅘🅙🅚🅛🅜🅝🅞🅟🅠🅡🅢🅣🅤🅥🅦🅧🅨🅩"
                },
                parenthesized: {
                    from: "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcde" \
                          "fghijklmnopqrstuvwxyz",
                    to: "⑴⑵⑶⑷⑸⑹⑺⑻⑼🄐🄑🄒🄓🄔🄕🄖🄗🄘🄙🄚🄛🄜🄝🄞🄟🄠🄡🄢🄣🄤🄥🄦🄧🄨🄩⒜⒝⒞⒟⒠" \
                        "⒡⒢⒣⒤⒥⒦⒧⒨⒩⒪⒫⒬⒭⒮⒯⒰⒱⒲⒳⒴⒵"
                },
                squared: {
                    from: "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
                    to: "🄰🄱🄲🄳🄴🄵🄶🄷🄸🄹🄺🄻🄼🄽🄾🄿🅀🅁🅂🅃🅄🅅🅆🅇🅈🅉"
                },
                negative_squared: {
                    from: "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
                    to: "🅰🅱🅲🅳🅴🅵🅶🅷🅸🅹🅺🅻🅼🅽🅾🅿🆀🆁🆂🆃🆄🆅🆆🆇🆈🆉"
                },
                fullwidth: {
                    from: "!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGH" \
                          "IJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnop" \
                          "qrstuvwxyz{|}~ ",
                    to: "！＂＃＄％＆＇（）＊＋，－．／０１２３４５６７８９：；＜＝＞？＠ＡＢＣＤＥＦＧＨ" \
                        "ＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ［＼］＾＿｀ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐ" \
                        "ｑｒｓｔｕｖｗｘｙｚ｛｜｝～　"
                }
            }.freeze
        end

        FORMS = MathForms::FORMS.merge(OtherForms::FORMS).freeze
    end
end
