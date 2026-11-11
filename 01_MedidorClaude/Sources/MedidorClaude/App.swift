import SwiftUI

// MARK: - Dados (lidos de ~/.claude/medidor/usage.json, escrito pela status line)

struct Limite: Decodable { var used_percentage: Double?; var resets_at: Double? }
struct Limites: Decodable { var five_hour: Limite?; var seven_day: Limite? }
struct Contexto: Decodable { var used_percentage: Double?; var context_window_size: Double? }
struct ModeloInfo: Decodable { var display_name: String? }
struct Pasta: Decodable { var current_dir: String? }
struct Dados: Decodable { var transcript_path: String?; var rate_limits: Limites?; var context_window: Contexto?; var session_id: String?; var cwd: String?; var model: ModeloInfo?; var workspace: Pasta? }

struct Sessao: Identifiable {
    let id: String, nome: String, modelo: String, ctx: Double, tam: Double?, ultima: Date?, quando: Date
    var parada: Bool { Date().timeIntervalSince(quando) > 600 }
}

enum Saude {
    case saudavel, atencao, pesada, novaSessao
    init(_ p: Double) {
        switch p { case ..<50: self = .saudavel; case ..<80: self = .atencao
                   case ..<96: self = .pesada; default: self = .novaSessao }
    }
    var titulo: String { ["saudavel": "Sessão saudável", "atencao": "Atenção", "pesada": "Sessão pesada", "novaSessao": "Hora de uma nova sessão"][key]! }
    var dica: String { ["saudavel": "Pode trabalhar sem preocupação.", "atencao": "Metade da janela já foi usada.", "pesada": "Termine o que está em andamento.", "novaSessao": "Salve o progresso e comece outra sessão."][key]! }
    var key: String { switch self { case .saudavel: "saudavel"; case .atencao: "atencao"; case .pesada: "pesada"; case .novaSessao: "novaSessao" } }
    var cor: Color { switch self { case .saudavel: .green; case .atencao: .yellow; case .pesada: .orange; case .novaSessao: .red } }
    var simbolo: String { switch self { case .saudavel: "checkmark.circle.fill"; case .atencao: "exclamationmark.circle.fill"; case .pesada: "flame.circle.fill"; case .novaSessao: "arrow.triangle.2.circlepath.circle.fill" } }
}

@MainActor final class Modelo: ObservableObject {
    @Published var dados: Dados?
    @Published var atualizado: Date?
    @Published var agora = Date()
    @Published var sessoes: [Sessao] = []
    private let url = URL(fileURLWithPath: NSHomeDirectory() + "/.claude/medidor/usage.json")
    private var timer: Timer?

    init() { ler(); timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in Task { @MainActor in self?.ler() } } }

    struct Processo: Decodable { var pid: Int32?; var sessionId: String?; var cwd: String? }

    // Sessões abertas = processos do Claude Code vivos (~/.claude/sessions/<pid>.json);
    // a saúde vem do que a status line gravou em ~/.claude/medidor/sessions/<id>.json.
    func lerSessoes() {
        let fm = FileManager.default
        let reg = NSHomeDirectory() + "/.claude/sessions"
        let med = NSHomeDirectory() + "/.claude/medidor/sessions"
        var out: [Sessao] = []
        var vistos = Set<String>()
        for f in (try? fm.contentsOfDirectory(atPath: reg)) ?? [] where f.hasSuffix(".json") {
            guard let d = try? Data(contentsOf: URL(fileURLWithPath: reg + "/" + f)),
                  let p = try? JSONDecoder().decode(Processo.self, from: d),
                  let pid = p.pid, let sid = p.sessionId, kill(pid, 0) == 0, !vistos.contains(sid) else { continue }
            vistos.insert(sid)
            let mp = med + "/" + sid + ".json"
            var ctx = 0.0, tam: Double? = nil, ultima: Date? = nil, quando = Date.distantPast, modelo = ""
            if let md = try? Data(contentsOf: URL(fileURLWithPath: mp)), let v = try? JSONDecoder().decode(Dados.self, from: md) {
                ctx = v.context_window?.used_percentage ?? 0
                modelo = v.model?.display_name ?? ""
                tam = v.context_window?.context_window_size
                if let t = v.transcript_path { ultima = (try? fm.attributesOfItem(atPath: t)[.modificationDate]) as? Date }
                quando = (try? fm.attributesOfItem(atPath: mp)[.modificationDate]) as? Date ?? .distantPast
            }
            out.append(Sessao(id: sid, nome: ((p.cwd ?? "Sessão") as NSString).lastPathComponent, modelo: modelo, ctx: ctx, tam: tam, ultima: ultima, quando: quando))
        }
        sessoes = out.sorted { $0.quando > $1.quando }
        // limpa arquivos de sessões que já fecharam
        for f in (try? fm.contentsOfDirectory(atPath: med)) ?? [] where !vistos.contains((f as NSString).deletingPathExtension) {
            let path = med + "/" + f
            if let t = (try? fm.attributesOfItem(atPath: path)[.modificationDate]) as? Date, Date().timeIntervalSince(t) > 600 { try? fm.removeItem(atPath: path) }
        }
    }

    func ler() {
        agora = Date()
        lerSessoes()
        guard let d = try? Data(contentsOf: url), let v = try? JSONDecoder().decode(Dados.self, from: d) else { return }
        dados = v
        atualizado = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
    }
    var h: Double { dados?.rate_limits?.five_hour?.used_percentage ?? 0 }
    var s: Double { dados?.rate_limits?.seven_day?.used_percentage ?? 0 }
    var c: Double { dados?.context_window?.used_percentage ?? 0 }
    func iconeBarra() -> NSImage {
        let cores = sessoes.prefix(6).map { NSColor(saude($0).cor) }
        let n = sessoes.count
        let altura: CGFloat = 18, d: CGFloat = 11, gap: CGFloat = 4
        let texto = "\(n)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.labelColor]
        let tw = texto.size(withAttributes: attrs).width
        let pontosW = cores.isEmpty ? 0 : CGFloat(cores.count) * (d + gap)
        let img = NSImage(size: NSSize(width: pontosW + tw + 2, height: altura), flipped: false) { _ in
            var x: CGFloat = 0
            for c in cores { c.setFill(); NSBezierPath(ovalIn: NSRect(x: x, y: (altura - d) / 2, width: d, height: d)).fill(); x += d + gap }
            texto.draw(at: NSPoint(x: x, y: (altura - 15) / 2), withAttributes: attrs)
            return true
        }
        img.isTemplate = false
        return img
    }
    var globalPct: Double { max(h, s) }
    var saude: Saude { Saude(max(globalPct, sessoes.map(\.ctx).max() ?? c)) }
    func saude(_ x: Sessao) -> Saude { Saude(max(globalPct, x.ctx)) }
    var temDados: Bool { dados?.rate_limits?.five_hour != nil }
    var antigo: Bool { atualizado.map { agora.timeIntervalSince($0) > 600 } ?? true }

    func restante(_ epoch: Double?) -> String {
        guard let e = epoch else { return "—" }
        let seg = max(0, Int(e - agora.timeIntervalSince1970))
        if seg >= 86400 { return "\(seg / 86400) d \((seg % 86400) / 3600) h" }
        return "\(seg / 3600) h \(String(format: "%02d", (seg % 3600) / 60)) min"
    }
}

// MARK: - Visual

func corNivel(_ p: Double) -> Color { Saude(p).cor }

struct Anel: View {
    let titulo: String, simbolo: String, pct: Double, reinicio: String
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 14)
                Circle().trim(from: 0, to: min(pct, 100) / 100)
                    .stroke(AngularGradient(colors: [corNivel(pct).opacity(0.6), corNivel(pct)], center: .center),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth, value: pct)
                VStack(spacing: 0) {
                    Text("\(Int(pct.rounded()))").font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text("%").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 112, height: 112)
            Text(titulo).font(.headline)
            Label(reinicio, systemImage: "arrow.clockwise")
                .font(.system(size: 13, weight: .medium))
                .imageScale(.large)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LinhaSessao: View {
    let x: Sessao, saude: Saude
    func tok(_ n: Double) -> String { n >= 1_000_000 ? String(format: "%.1f M", n / 1_000_000) : "\(Int((n / 1000).rounded())) mil" }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: saude.simbolo).font(.system(size: 26)).foregroundStyle(saude.cor)
            VStack(alignment: .leading, spacing: 3) {
                Text(x.nome).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                HStack(spacing: 6) {
                    Text(saude.titulo).font(.system(size: 12)).foregroundStyle(saude.cor)
                    if x.parada { Text("· parada").font(.system(size: 12)).foregroundStyle(.secondary) }
                }
                if let u = x.ultima {
                    let rest = Int(3600 - Date().timeIntervalSince(u))
                    let min = max(0, (rest + 59) / 60)
                    HStack(spacing: 6) {
                        if rest > 1800 {
                            Text("🔥").font(.system(size: 16))
                            Text("ativo \(min) min").foregroundStyle(.orange)
                        } else if rest > 600 {
                            Text("💨").font(.system(size: 16))
                            Text("esfriando \(min) min").foregroundStyle(.secondary)
                        } else if rest > 0 {
                            Text("💀").font(.system(size: 16))
                            Text("acabando \(min) min").foregroundStyle(.red)
                        } else {
                            Text("💀").font(.system(size: 16))
                            Text("expirado").foregroundStyle(.red)
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int(x.ctx.rounded()))%").font(.system(size: 15, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(x.tam.map { "\(tok($0 * x.ctx / 100)) de \(tok($0))" } ?? "contexto").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(x.parada ? 0.65 : 1)
    }
}

struct Painel: View {
    @ObservedObject var m: Modelo
    var body: some View {
        VStack(spacing: 18) {
            if m.temDados {
                HStack(alignment: .top, spacing: 8) {
                    Anel(titulo: "Janela de 5 h", simbolo: "clock", pct: m.h, reinicio: m.restante(m.dados?.rate_limits?.five_hour?.resets_at))
                    Anel(titulo: "Semana", simbolo: "calendar", pct: m.s, reinicio: m.restante(m.dados?.rate_limits?.seven_day?.resets_at))
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "hourglass").font(.system(size: 30)).foregroundStyle(.secondary)
                    Text("Aguardando dados").font(.headline)
                    Text("Os limites aparecem depois da primeira resposta do Claude Code.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.padding(.vertical, 20)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(m.sessoes.count == 1 ? "1 sessão aberta" : "\(m.sessoes.count) sessões abertas", systemImage: "terminal").font(.system(size: 14, weight: .semibold)).imageScale(.large)
                    Spacer()
                }
                if m.sessoes.isEmpty {
                    Text("Nenhuma sessão ativa ainda.").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(m.sessoes) { x in LinhaSessao(x: x, saude: m.saude(x)) }
                }
            }

            HStack {
                if m.antigo && m.temDados {
                    Label("Sem atualização recente", systemImage: "wifi.slash").font(.footnote).foregroundStyle(.orange)
                } else if let a = m.atualizado {
                    Text("Atualizado \(a.formatted(.relative(presentation: .named)))").font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Button("") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q").opacity(0).frame(width: 0, height: 0)
            }
        }
        .padding(20)
        .frame(width: 340)
    }
}

@main struct MedidorClaudeApp: App {
    @StateObject private var m = Modelo()
    var body: some Scene {
        MenuBarExtra {
            Painel(m: m)
        } label: {
            Image(nsImage: m.iconeBarra())
        }
        .menuBarExtraStyle(.window)
    }
}
