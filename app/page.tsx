"use client";

import { FormEvent, useEffect, useRef, useState } from "react";
import Image from "next/image";

type Trade = "eletricista" | "canalizador";
type ChatMessage = { from: "rumar" | "user"; text: string };

const tradeData = {
  eletricista: {
    label: "Eletricista",
    greeting: "Gonçalo",
    jobs: [
      { time: "09:00", title: "Quadro dispara com o forno", client: "Carla Mendes · Campo de Ourique", tag: "Diagnóstico", tone: "red" },
      { time: "11:30", title: "Instalar wallbox 7,4 kW", client: "João Brito · Alvalade", tag: "Confirmado", tone: "green" },
      { time: "15:00", title: "Trocar 6 tomadas e 2 apliques", client: "D. Emília · Benfica", tag: "Materiais prontos", tone: "blue" },
    ],
    stock: "Faltam 2 disjuntores C16 para amanhã",
    memory: "Quadro Hager · monofásico · fotos de 12/03",
    quick: "Trocar diferencial e verificar fuga no circuito da cozinha",
  },
  canalizador: {
    label: "Canalizador",
    greeting: "Gonçalo",
    jobs: [
      { time: "08:30", title: "Fuga de água sob o lava-loiça", client: "Marta Silva · Estrela", tag: "Urgente", tone: "red" },
      { time: "11:00", title: "Substituir termoacumulador", client: "Pedro Lima · Areeiro", tag: "Confirmado", tone: "green" },
      { time: "14:30", title: "Desentupir coluna de esgoto", client: "Condomínio Azul · Graça", tag: "Acesso confirmado", tone: "blue" },
    ],
    stock: "Leva 2 válvulas de segurança de 1/2\"",
    memory: "Tubagem multicamada · contador na garagem · fotos de 08/05",
    quick: "Substituir torneira e verificar pressão da rede na cozinha",
  },
};

function Mark({ children }: { children: React.ReactNode }) {
  return <span className="mark" aria-hidden="true">{children}</span>;
}

export default function Home() {
  const [trade, setTrade] = useState<Trade>("eletricista");
  const [activeNav, setActiveNav] = useState("Hoje");
  const [listening, setListening] = useState(false);
  const [voiceDraft, setVoiceDraft] = useState(false);
  const [toast, setToast] = useState("");
  const [chatOpen, setChatOpen] = useState(false);
  const [input, setInput] = useState("");
  const [messages, setMessages] = useState<ChatMessage[]>([
    { from: "rumar", text: "Bom dia! Organizei o teu dia e confirmei as duas visitas da manhã." },
  ]);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const data = tradeData[trade];

  useEffect(() => () => { if (timer.current) clearTimeout(timer.current); }, []);

  function notify(message: string) {
    setToast(message);
    window.setTimeout(() => setToast(""), 2600);
  }

  function startVoice() {
    if (listening) return;
    setListening(true);
    setVoiceDraft(false);
    timer.current = setTimeout(() => {
      setListening(false);
      setVoiceDraft(true);
    }, 1800);
  }

  function sendMessage(event: FormEvent) {
    event.preventDefault();
    const value = input.trim();
    if (!value) return;
    setMessages((current) => [...current, { from: "user", text: value }]);
    setInput("");
    setTimeout(() => {
      setMessages((current) => [...current, {
        from: "rumar",
        text: "Trato disso. Já criei um rascunho e deixei-o pronto para confirmares antes de enviar ao cliente.",
      }]);
    }, 500);
  }

  return (
    <main className="app-shell">
      <aside className="sidebar">
        <div className="brand-row">
          <div className="brand-symbol"><Image src="/rumar-mark.png" alt="" width={29} height={29} priority /></div>
          <div><strong>RUMAR</strong><span>sistema técnico</span></div>
        </div>

        <div className="trade-switch" aria-label="Escolher profissão">
          {(["eletricista", "canalizador"] as Trade[]).map((item) => (
            <button key={item} className={trade === item ? "selected" : ""} onClick={() => setTrade(item)}>
              <span>{item === "eletricista" ? "ϟ" : "◉"}</span>{tradeData[item].label}
            </button>
          ))}
        </div>

        <nav aria-label="Navegação principal">
          {[
            ["Hoje", "⌂"], ["Trabalhos", "▤"], ["Clientes", "♙"], ["Materiais", "◇"], ["Dinheiro", "€"],
          ].map(([label, icon]) => (
            <button key={label} className={activeNav === label ? "active" : ""} onClick={() => { setActiveNav(label); notify(`${label}: área pronta para a próxima versão`); }}>
              <Mark>{icon}</Mark>{label}{label === "Trabalhos" && <span className="nav-count">6</span>}
            </button>
          ))}
        </nav>

        <div className="sidebar-bottom">
          <div className="week-card">
            <span>ESTA SEMANA</span>
            <strong>€ 2.840</strong>
            <small>+18% do que planeaste</small>
          </div>
          <button className="profile" onClick={() => notify("Perfil e preferências") }>
            <span className="avatar">G</span>
            <span><strong>{data.greeting}</strong><small>{data.label}</small></span>
            <b>···</b>
          </button>
        </div>
      </aside>

      <section className="main-area">
        <header className="topbar">
          <div>
            <p>O teu dia de trabalho</p>
            <h1>Bom dia, {data.greeting}.</h1>
          </div>
          <div className="top-actions">
            <button className="icon-button" aria-label="Pesquisar" onClick={() => notify("Pesquisa aberta")}>⌕</button>
            <button className="icon-button notification" aria-label="Notificações" onClick={() => notify("Tens 3 novidades")}>♢<i /></button>
            <button className="new-job" onClick={() => setChatOpen(true)}><span>＋</span> Novo trabalho</button>
          </div>
        </header>

        <div className="content-grid">
          <section className="work-column">
            <article className="assistant-brief">
              <div className="assistant-orb"><span>R</span><i /></div>
              <div className="brief-copy">
                <p>A RUMAR JÁ ADIANTOU TRABALHO</p>
                <h2>O essencial está tratado.</h2>
                <span>Confirmei 2 visitas, preparei 1 orçamento e detetei um conflito na agenda.</span>
              </div>
              <button onClick={() => setChatOpen(true)}>Ver o resumo <span>→</span></button>
            </article>

            <div className="section-heading">
              <div><h2>Hoje</h2><span>3 trabalhos · 5h30 previstas</span></div>
              <button onClick={() => notify("Agenda semanal aberta")}>Ver agenda <span>→</span></button>
            </div>

            <div className="job-list">
              {data.jobs.map((job, index) => (
                <article className="job-card" key={job.time}>
                  <div className="job-time"><strong>{job.time}</strong><span>{index === 1 ? "1h 30" : "1h"}</span></div>
                  <div className={`job-line ${job.tone}`} />
                  <div className="job-info">
                    <div><h3>{job.title}</h3><p><Mark>⌖</Mark>{job.client}</p></div>
                    <div className="job-meta">
                      <span className={`tag ${job.tone}`}>{job.tag}</span>
                      <button aria-label={`Abrir ${job.title}`} onClick={() => notify(`Abriste: ${job.title}`)}>›</button>
                    </div>
                  </div>
                </article>
              ))}
            </div>

            <article className="materials-note">
              <div><Mark>◇</Mark><span><small>NOTA RUMAR</small><strong>{data.stock}</strong></span></div>
              <button onClick={() => notify("Lista de compra criada")}>Criar lista de compra</button>
            </article>

            <section className="memory-section">
              <div className="section-heading compact">
                <div><h2>A memória das tuas obras</h2><span>Cada casa fica mais fácil na visita seguinte.</span></div>
              </div>
              <div className="memory-card">
                <div className="home-thumb"><span>⌂</span></div>
                <div><small>RUA SARAIVA DE CARVALHO, 192</small><strong>{data.memory}</strong><span>3 intervenções · última há 2 meses</span></div>
                <button onClick={() => notify("Ficha da casa aberta")}>Ver ficha →</button>
              </div>
            </section>
          </section>

          <aside className="rumar-column">
            <div className="rumar-card">
              <div className="rumar-card-head">
                <div className="mini-orb">R<i /></div>
                <div><strong>RUMAR</strong><span><i /> A trabalhar contigo</span></div>
                <button aria-label="Mais opções">···</button>
              </div>

              <div className="chat-body">
                <div className="chat-date">HOJE, 08:12</div>
                <div className="bubble rumar">Bom dia, {data.greeting}! Organizei o teu dia e confirmei as duas visitas da manhã.</div>
                <div className="bubble rumar highlight"><span>⚠</span><div><strong>Conflito resolvido</strong><p>A visita da D. Emília passou para as 15:00. Ela já confirmou.</p></div></div>
                <div className="bubble rumar action-bubble">
                  <small>ORÇAMENTO PRONTO</small>
                  <strong>{data.quick}</strong>
                  <div><b>€ 186,40</b><button onClick={() => notify("Orçamento pronto. O envio requer ligar o WhatsApp.")}>Rever e enviar</button></div>
                </div>
                {voiceDraft && (
                  <div className="bubble rumar fresh"><strong>Entendi a tua nota.</strong><p>Preparei um rascunho de trabalho com 1h30 e os materiais sugeridos para confirmares.</p></div>
                )}
              </div>

              <div className="quick-asks">
                <button onClick={() => notify("Resumo de recebimentos: €940 pendentes")}>Quanto falta receber?</button>
                <button onClick={() => notify("Há uma janela livre amanhã às 11:30")}>Tenho espaço amanhã?</button>
              </div>

              <div className={`voice-box ${listening ? "listening" : ""}`}>
                <button className="voice-button" onClick={startVoice} aria-label="Gravar nota de voz">{listening ? "■" : "●"}</button>
                <div><strong>{listening ? "Estou a ouvir…" : "Fala com a RUMAR"}</strong><span>{listening ? "Diz o que precisas, sem tirar as mãos do trabalho." : "Carrega e deixa uma nota de voz"}</span></div>
                <div className="sound-bars" aria-hidden="true"><i /><i /><i /><i /><i /></div>
              </div>
            </div>

            <div className="promise-card">
              <div><span>5h</span><small>poupadas / semana</small></div>
              <p>Menos papelada.<br /><strong>Mais trabalho fechado.</strong></p>
            </div>
          </aside>
        </div>
      </section>

      {chatOpen && (
        <div className="modal-backdrop" role="presentation" onMouseDown={() => setChatOpen(false)}>
          <section className="chat-modal" role="dialog" aria-modal="true" aria-label="Falar com a RUMAR" onMouseDown={(event) => event.stopPropagation()}>
            <header><div className="mini-orb">R<i /></div><div><strong>Fala com a RUMAR</strong><span>Prepara ações para confirmares</span></div><button onClick={() => setChatOpen(false)} aria-label="Fechar">×</button></header>
            <div className="modal-messages">
              {messages.map((message, index) => <div key={index} className={`bubble ${message.from}`}>{message.text}</div>)}
            </div>
            <form onSubmit={sendMessage}><input value={input} onChange={(event) => setInput(event.target.value)} autoFocus placeholder="Ex.: cria um trabalho para amanhã às 10h…" aria-label="Mensagem" /><button aria-label="Enviar">↑</button></form>
          </section>
        </div>
      )}

      {toast && <div className="toast" role="status"><span>✓</span>{toast}</div>}
    </main>
  );
}
