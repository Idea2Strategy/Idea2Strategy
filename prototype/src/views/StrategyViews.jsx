import { useState } from 'react';
import { ArrowLeft, Boxes, Check, ChevronDown, CircleDollarSign, Copy, GitBranch, Layers3, LockKeyhole, Play, Plus, Save, Search, ShieldCheck, Sparkles, Split, Timer, X } from 'lucide-react';
import { strategies, templates } from '../data/mockData.js';
import { Button, DataTable, FilterButton, HelpNote, PageHeading, Panel, SearchBar, StatCard, Status } from '../components/common.jsx';

const statusTone = (state) => state === '검증 완료' ? 'positive' : state === '입력 필요' ? 'warning' : 'neutral';

export function StrategyHome({ openEditor }) {
  const columns = [
    { key: 'name', label: '전략', render: (row) => <button className="table-primary" onClick={() => openEditor(row.mode.toLowerCase())}><span className={`mode-mark mode-${row.mode.toLowerCase()}`}>{row.mode[0]}</span><span><strong>{row.name}</strong><small>{row.blocks} blocks · {row.updated}</small></span></button> },
    { key: 'mode', label: '모드' },
    { key: 'state', label: '검증', render: (row) => <Status tone={statusTone(row.state)}>{row.state}</Status> },
    { key: 'backtest', label: '백테스트' },
    { key: 'action', label: '', render: (row) => <Button kind="ghost" onClick={() => openEditor(row.mode.toLowerCase())}>열기</Button> },
  ];
  return <div className="page strategy-home">
    <PageHeading eyebrow="STRATEGY WORKSPACE" title="전략 스튜디오" description="전략을 작성하고 검증한 뒤 잠긴 버전으로 출시합니다." actions={<><Button icon={Copy}>기존 전략 복사</Button><Button kind="primary" icon={Plus} onClick={() => openEditor('basic')}>새 전략</Button></>} />
    <div className="stats-grid three"><StatCard label="작업본" value="03" detail="미저장 변경 없음" icon={Layers3} /><StatCard label="검증 준비" value="01" detail="출시 전 확인 가능" trend="READY" icon={ShieldCheck} /><StatCard label="출시 전략" value="08" detail="자동 백테스트 7/8" icon={LockKeyhole} /></div>
    <div className="content-grid strategy-grid">
      <Panel className="span-2" title="내 전략" subtitle="현재 작업본과 출시된 상태" action={<div className="toolbar-inline"><SearchBar placeholder="전략 검색" /><FilterButton /></div>}><DataTable columns={columns} rows={strategies} /></Panel>
      <Panel title="빠른 시작" subtitle="모든 필수 값은 비어 있습니다"><div className="template-list">{templates.map((template) => <button key={template.name} className="template-card" onClick={() => openEditor(template.type === 'Pro' ? 'pro' : 'basic')}><span className={`template-type type-${template.type === '매수' ? 'buy' : template.type === '매도' ? 'sell' : 'pro'}`}>{template.type}</span><strong>{template.name}</strong><small>{template.detail}</small><span className="template-fields">필수 입력 {template.fields}</span></button>)}</div><HelpNote>템플릿은 구조만 제공하며 종목·기간·수치·비중을 제안하지 않습니다.</HelpNote></Panel>
    </div>
  </div>;
}

const Block = ({ icon: Icon, label, value, op, tone = 'neutral' }) => <div className={`scratch-block block-${tone}`}>{Icon && <Icon size={15} />}<span>{label}</span>{op && <b className="block-op">{op}</b>}{value && <button className="block-value">{value}<ChevronDown size={12} /></button>}</div>;
const Translation = ({ children }) => <span className="block-translation">{children}</span>;

export function BasicEditor({ goBack }) {
  const [reviewBuy, setReviewBuy] = useState(false);
  const [reviewSell, setReviewSell] = useState(false);
  const [saved, setSaved] = useState(false);
  return <div className="page editor-page">
    <PageHeading eyebrow="BASIC · DRAFT" title="Basic 전략 편집기" description="블록을 위에서 아래로 맞물리며 각 종목을 독립적으로 평가합니다." meta={<Status tone={saved ? 'positive' : 'warning'}>{saved ? '저장됨' : '미저장 변경'}</Status>} actions={<><Button kind="ghost" icon={ArrowLeft} onClick={goBack}>목록</Button><Button icon={Save} onClick={() => setSaved(true)}>저장</Button><Button kind="primary" icon={ShieldCheck}>검증</Button></>} />
    <div className="editor-layout basic-layout">
      <aside className="editor-palette panel"><div className="palette-title"><span>BLOCKS</span><Search size={15} /></div><label className="palette-search"><Search size={14} /><input aria-label="블록 검색" placeholder="RSI, 가격, 체결량" /></label>{['시작', '조건 · 지표', '실행 제한', '주문 행동', '예산 · 배분'].map((group, index) => <div className="palette-group" key={group}><button><span>{group}</span><span>{index === 1 ? '12' : index + 3}</span></button>{index === 1 && <div className="palette-items"><span>RSI</span><span>이동평균</span><span>거래량</span></div>}</div>)}<div className="palette-template"><Sparkles size={17} /><div><strong>구조 템플릿</strong><small>값이 비어 있는 시작점</small></div></div></aside>
      <section className="editor-canvas basic-canvas" aria-label="Basic 전략 캔버스"><div className="canvas-toolbar"><span>Opening Range Flow</span><span className="canvas-zoom">− &nbsp; 100% &nbsp; +</span></div><div className="mobile-editor-notice"><Boxes size={24} /><strong>전략 편집은 데스크톱에서 사용할 수 있습니다</strong><span>현재 화면에서는 구성만 조회할 수 있습니다.</span></div><div className="scratch-workspace">
        <div className="strategy-container buy-container" data-testid="basic-buy-group" tabIndex="0" onMouseEnter={() => setReviewBuy(true)} onMouseLeave={() => setReviewBuy(false)} onFocus={() => setReviewBuy(true)} onBlur={() => setReviewBuy(false)}><header><span className="container-symbol">B</span><div><strong>매수 전략</strong><small>가격 갱신 · 종목별 평가</small></div><span>4 BLOCKS</span></header><div className="block-stack">
          <div className="block-with-copy"><Block icon={Play} label="1m BAR" tone="trigger" />{reviewBuy && <Translation>새로운 1분봉이 완성되고</Translation>}</div>
          <div className="block-with-copy"><Block icon={Timer} label="RSI" op="<" value="30" tone="condition" />{reviewBuy && <Translation>RSI가 입력한 기준 아래로 내려오면</Translation>}</div>
          <div className="block-with-copy"><Block icon={CircleDollarSign} label="BUDGET" value="25%" tone="budget" />{reviewBuy && <Translation>현재 전략 예산의 25%를 확인하고</Translation>}</div>
          <div className="block-with-copy"><Block icon={Check} label="BUY" value="MARKET" tone="buy" />{reviewBuy && <Translation>설정한 비율만큼 매수 후보를 만듭니다</Translation>}</div><button className="block-add"><Plus size={14} /> 블록 추가</button></div></div>
        <div className="strategy-container sell-container" data-testid="basic-sell-group" tabIndex="0" onMouseEnter={() => setReviewSell(true)} onMouseLeave={() => setReviewSell(false)} onFocus={() => setReviewSell(true)} onBlur={() => setReviewSell(false)}><header><span className="container-symbol">S</span><div><strong>매도 전략</strong><small>포지션 상태 · 종목별 평가</small></div><span>3 BLOCKS</span></header><div className="block-stack">
          <div className="block-with-copy"><Block icon={Play} label="POSITION" value="OPEN" tone="trigger" />{reviewSell && <Translation>포지션을 보유하고 있을 때</Translation>}</div>
          <div className="block-with-copy"><Block icon={Timer} label="RSI" op=">" value="70" tone="condition" />{reviewSell && <Translation>RSI가 입력한 기준 위로 올라가면</Translation>}</div>
          <div className="block-with-copy"><Block icon={Check} label="SELL" value="100%" tone="sell" />{reviewSell && <Translation>보유 수량 전체의 매도 후보를 만듭니다</Translation>}</div><button className="block-add"><Plus size={14} /> 블록 추가</button></div></div>
      </div></section>
      <aside className="editor-inspector panel"><div className="inspector-title"><span>STRATEGY</span><button aria-label="닫기"><X size={15} /></button></div><div className="inspector-section"><label>전략 이름</label><input value="Opening Range Flow" readOnly /></div><div className="inspector-section"><label>대상 종목</label><button className="select-field">AAPL · MSFT · SPY <ChevronDown size={14} /></button></div><div className="inspector-section"><label>예산 상한</label><div className="input-split"><input value="40" readOnly /><span>%</span></div></div><div className="inspector-section"><label>배분</label><span className="locked-field"><LockKeyhole size={14} /> 균등 배분 · Basic 고정</span></div><HelpNote>블록 묶음에 마우스를 올리거나 키보드로 초점을 이동하면 전략 문장을 확인할 수 있습니다.</HelpNote></aside>
    </div>
  </div>;
}

const GraphNode = ({ className = '', icon: Icon, kicker, title, detail, outputs = [], x, y, children }) => <article className={`graph-node ${className}`} style={{ left: x, top: y }}><header>{Icon && <Icon size={15} />}<span>{kicker}</span><button aria-label={`${title} 메뉴`}>•••</button></header><strong>{title}</strong><small>{detail}</small>{children}{outputs.length > 0 && <div className="node-outputs">{outputs.map((output) => <span key={output.label} className={`node-output output-${output.tone}`}><small>{output.label}</small><i /></span>)}</div>}</article>;

export function ProEditor({ goBack }) {
  const [picker, setPicker] = useState(null);
  const [addedNode, setAddedNode] = useState(false);
  const releaseConnection = (event) => setPicker({ x: event.clientX, y: event.clientY });
  return <div className="page editor-page pro-page"><PageHeading eyebrow="PRO · DRAFT" title="Pro 전략 편집기" description="타입이 맞는 노드를 좌우로 연결해 분기·다종목·자금 정책을 명시합니다." meta={<Status tone="warning">필수 정책 2개 남음</Status>} actions={<><Button kind="ghost" icon={ArrowLeft} onClick={goBack}>목록</Button><Button icon={Save}>저장</Button><Button kind="primary" icon={ShieldCheck}>검증</Button></>} />
    <div className="pro-editor-shell"><aside className="pro-rail panel"><Search size={17} />{[['TRG', Play], ['VAL', Layers3], ['LOG', GitBranch], ['ORD', CircleDollarSign], ['POL', ShieldCheck]].map(([label, Icon], index) => <button key={label} className={index === 1 ? 'active' : ''}><Icon size={17} /><span>{label}</span></button>)}</aside>
      <section className="editor-canvas pro-canvas" onClick={() => picker && setPicker(null)}><div className="canvas-toolbar"><span>Pair Spread Monitor · v0.8</span><span className="canvas-zoom">GRID 16 &nbsp; · &nbsp; 82%</span></div><div className="mobile-editor-notice"><Split size={24} /><strong>Pro 그래프 편집은 데스크톱 전용입니다</strong><span>넓은 화면에서 연결과 노드 배치를 편집하세요.</span></div><svg className="graph-links" viewBox="0 0 1120 600" aria-hidden="true"><path d="M210 208 C280 208 270 154 340 154" /><path d="M505 154 C560 154 550 122 615 122" /><path d="M505 168 C560 168 550 305 615 305" className="link-false" /><path d="M780 122 C840 122 820 228 890 228" /><path d="M780 305 C840 305 820 246 890 246" className="link-false" /></svg>
        <GraphNode icon={Play} kicker="TRIGGER" title="Bar closed" detail="1 minute · regular session" x={48} y={150} outputs={[{ label: 'event', tone: 'event' }]} />
        <GraphNode icon={GitBranch} kicker="CONDITION" title="Spread threshold" detail="z-score · user input" x={340} y={98} outputs={[{ label: 'true', tone: 'true' }, { label: 'false', tone: 'false' }]}><button data-testid="true-output" className="connection-handle true-handle" aria-label="true 출력 연결" onPointerUp={releaseConnection}><span>TRUE</span><i /></button></GraphNode>
        <GraphNode icon={CircleDollarSign} kicker="CANDIDATE" title="Open pair" detail="two order intents" x={615} y={66} outputs={[{ label: 'candidate', tone: 'event' }]} /><GraphNode icon={Timer} kicker="STATE" title="Wait next event" detail="no order candidate" x={615} y={249} outputs={[{ label: 'state', tone: 'false' }]} /><GraphNode icon={ShieldCheck} kicker="FINALIZE" title="Order processor" detail="deduplicate · budget · risk" x={890} y={172} outputs={[{ label: 'orders', tone: 'true' }]} />{addedNode && <GraphNode className="new-node" icon={ShieldCheck} kicker="CONDITION" title="Position check" detail="explicit state condition" x={545} y={410} outputs={[{ label: 'true', tone: 'true' }, { label: 'false', tone: 'false' }]} />}
        {picker && <div role="dialog" aria-label="호환 노드 선택" className="node-picker" style={{ left: `${picker.x}px`, top: `${picker.y}px` }} onClick={(event) => event.stopPropagation()}><header><div><span>TRUE OUTPUT</span><strong>호환 노드 선택</strong></div><button aria-label="호환 노드 선택 닫기" onClick={() => setPicker(null)}><X size={15} /></button></header><label><Search size={14} /><input autoFocus aria-label="호환 노드 검색" placeholder="노드 검색" /></label><p>조건 · 비교</p><button aria-label="포지션 확인" onClick={() => { setAddedNode(true); setPicker(null); }}><ShieldCheck size={16} /><span><strong>포지션 확인</strong><small>보유 수량과 상태 비교</small></span><kbd>↵</kbd></button><button aria-label="값 비교"><GitBranch size={16} /><span><strong>값 비교</strong><small>같은 타입의 두 값 비교</small></span></button><p>주문 후보</p><button aria-label="매수 후보"><CircleDollarSign size={16} /><span><strong>매수 후보</strong><small>시장 주문 후보 생성</small></span></button></div>}<div className="graph-minimap"><span /><i /><b /></div>
      </section><aside className="node-inspector panel"><div className="inspector-title"><span>NODE SETTINGS</span><button aria-label="설정 닫기"><X size={15} /></button></div><div className="node-id">CONDITION · 04</div><h3>Spread threshold</h3><div className="inspector-section"><label>Left value</label><button className="select-field">Pair z-score <ChevronDown size={14} /></button></div><div className="inspector-section"><label>Operator</label><button className="select-field">Greater than <ChevronDown size={14} /></button></div><div className="inspector-section"><label>User input</label><div className="empty-input"><span>값을 입력하세요</span><b>required</b></div></div><div className="port-legend"><span><i className="port true" /> TRUE · compatible 8</span><span><i className="port false" /> FALSE · compatible 6</span></div></aside>
    </div>
  </div>;
}
