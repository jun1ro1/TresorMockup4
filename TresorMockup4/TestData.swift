//
//  TestData.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/11/23.
//

import Foundation
import CoreData

class TestData {
    private static var manager: TestData? = nil
    static var shared: TestData = {
        if manager == nil {
            manager  = TestData()
        }
        return manager!
    }()
    
    func saveDummyData() {
        let titles = [
            "antipreparedness",
            "decaphyllous",
            "rightle",
            "scrunt",
            "transpanamic",
            "typhomalaria",
            "sapiential",
            "uteroventral",
            "uncinch",
            "isoantibody",
            "asaraceae",
            "argean",
            "arterioverter",
            "titianic",
            "entoptoscope",
            "indistinguished",
            "sundriesman",
            "comprisable",
            "kyu",
            "skeezix",
            "demitone",
            "intershade",
            "sitfast",
            "pashm",
            "unwhimsical",
            "transliterate",
            "suspirious",
            "reinduce",
            "melanoderma",
            "surround",
            "ganging",
            "turnsheet",
            "slugger",
            "tetramethylammonium",
            "rousement",
            "morphophyly",
            "tauromachic",
            "introconvertibility",
        ]
        
        let urls = [
            "https://auth.antipreparedness.ad.am",
            "https://www2.decaphyllous.co.gov",
            "https://rightle.ac.wf",
            "https://www8.scrunt.gr.ad",
            "https://www2.transpanamic.ne.ar",
            "https://www9.typhomalaria.lg.az",
            "https://sapiential.lg.am",
            "https://www3.uteroventral.or.mil",
            "https://www4.uncinch.or.je",
            "https://auth.isoantibody.ed.mo",
            "https://www4.asaraceae.or.tw",
            "https://www9.argean.ne.my",
            "https://www3.arterioverter.lg.gn",
            "https://auth.titianic.lg.pw",
            "https://www3.entoptoscope.gr.sv",
            "https://www3.indistinguished.or.lc",
            "https://auth.sundriesman.ne.info",
            "https://www0.comprisable.go.eu",
            "https://auth.kyu.bl",
            "https://www0.skeezix.gr.lk",
            "https://www8.demitone.ac.cg",
            "https://www5.intershade.ed.lt",
            "https://www5.sitfast.or.ye",
            "https://www6.pashm.co.in",
            "https://www5.unwhimsical.me",
            "https://www1.transliterate.ed.sj",
            "https://www4.suspirious.bl",
            "https://www.reinduce.ac.gi",
            "https://melanoderma.co.mil",
            "https://www4.surround.co.np",
            "https://www9.ganging.go.na",
            "https://www7.turnsheet.go.th",
            "https://www.slugger.ed.vc",
            "https://www5.tetramethylammonium.ad.sh",
            "https://www8.rousement.or.yt",
            "https://morphophyly.lg.cw",
            "https://tauromachic.ed.is",
            "https://www6.introconvertibility.ed.to",
        ]
        
        let Deutsch = """
        https://ja.wikipedia.org/wiki/歓喜の歌

        An die Freude
           Johann Christoph Friedrich von Schiller

        O Freunde, nicht diese Töne!
        Sondern laßt uns angenehmere
        anstimmen und freudenvollere.

        Freude, schöner Götterfunken,
        Tochter aus Elysium
        Wir betreten feuertrunken.
        Himmlische, dein Heiligtum!

        Deine Zauber binden wieder,
        Was die Mode streng geteilt;
        Alle Menschen werden Brüder,
        Wo dein sanfter Flügel weilt.

        Wem der große Wurf gelungen,
        Eines Freundes Freund zu sein,
        Wer ein holdes Weib errungen,
        Mische seinen Jubel ein!

        Ja, wer auch nur eine Seele
        Sein nennt auf dem Erdenrund!
        Und wer's nie gekonnt, der stehle
        Weinend sich aus diesem Bund!

        Freude trinken alle Wesen
        An den Brüsten der Natur;
        Alle Guten, alle Bösen
        Folgen ihrer Rosenspur.

        Küsse gab sie uns und Reben,
        Einen Freund, geprüft im Tod;
        Wollust ward dem Wurm gegeben,
        und der Cherub steht vor Gott.

        Froh, wie seine Sonnen fliegen
        Durch des Himmels prächt'gen Plan,
        Laufet, Brüder, eure Bahn,
        Freudig, wie ein Held zum Siegen.

        Seid umschlungen, Millionen!
        Diesen Kuss der ganzen Welt!
        Brüder, über'm Sternenzelt
        Muß ein lieber Vater wohnen.

        Ihr stürzt nieder, Millionen?
        Ahnest du den Schöpfer, Welt?
        Such' ihn über'm Sternenzelt!
        Über Sternen muß er wohnen.
        """
        
        let Japanisch = """
        https://ja.wikipedia.org/wiki/歓喜の歌

        「歓喜に寄せて」
           ヨーハン・クリストフ・フリードリヒ・フォン・シラー

        おお友よ、このような音ではない！
        我々はもっと心地よい
        もっと歓喜に満ち溢れる歌を歌おうではないか

        歓喜よ、神々の麗しき霊感よ
        天上の楽園の乙女よ
        我々は火のように酔いしれて
        崇高な汝（歓喜）の聖所に入る

        汝が魔力は再び結び合わせる
        時流が強く切り離したものを
        すべての人々は兄弟となる
        汝の柔らかな翼が留まる所で

        ひとりの友の友となるという
        大きな成功を勝ち取った者
        心優しき妻を得た者は
        彼の歓声に声を合わせよ

        そうだ、地上にただ一人だけでも
        心を分かち合う魂があると言える者も歓呼せよ
        そしてそれがどうしてもできなかった者は
        この輪から泣く泣く立ち去るがよい

        すべての被造物は
        創造主の乳房から歓喜を飲み、
        すべての善人とすべての悪人は
        創造主の薔薇の踏み跡をたどる。

        口づけと葡萄酒と死の試練を受けた友を
        創造主は我々に与えた
        快楽は虫けらのような弱い人間にも与えられ
        智天使ケルビムは神の御前に立つ

        天の星々がきらびやかな天空を
        飛びゆくように、楽しげに
        兄弟たちよ、自らの道を進め
        英雄のように喜ばしく勝利を目指せ

        抱擁を受けよ、諸人（もろびと）よ！
        この口づけを全世界に！
        兄弟よ、この星空の上に
        ひとりの父なる神が住んでおられるに違いない

        諸人よ、ひざまずいたか
        世界よ、創造主を予感するか
        星空の彼方に神を求めよ
        星々の上に、神は必ず住みたもう
        """
        
        assert(titles.count == urls.count)
        let formatter = ISO8601DateFormatter()
        var sites: [Dictionary<String, String>] = []
        for i in 0..<titles.count {
            var site =
                [ "title": titles[i],
                  "titleSort": titles[i],
                  "url":   urls[i],
                  "userid":  "user-\(String(i))",
                  "password": "pass-\(String(i))",
                  "selectAt": formatter.string(from: Date())
                ]
            
            switch i {
            case 0:
                site["memo"] = Deutsch
            case 1:
                site["memo"] = Japanisch
            default:
                break
            }
            sites.append(site)
        }
        let viewContext = PersistenceController.shared.container.viewContext
        sites.forEach {
            let _ = Site(from: $0, context: viewContext)
        }
        
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}
