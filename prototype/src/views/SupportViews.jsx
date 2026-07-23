import { BellRing, Check, Database, KeyRound, LockKeyhole, Mail, ServerCog, ShieldCheck, UserRound, Wrench } from 'lucide-react';
import { Button, HelpNote, ListRow, PageHeading, Panel, Status } from '../components/common.jsx';
import { notifications } from '../data/mockData.js';
import { Localized } from '../lib/i18n.jsx';

export function NotificationsView() {
  return <Localized><div className="page narrow-page"><PageHeading eyebrow="INBOX" title="알림" description="봇 운영과 방 일정에 영향을 주는 사건을 한곳에서 확인합니다." actions={<Button icon={Check}>모두 읽음</Button>} /><Panel className="notification-panel" title="최근 알림" subtitle="미확인 2개">{notifications.map((item) => <button className={`notification-row ${item.unread ? 'unread' : ''}`} key={item.title}><span className="notification-mark"><BellRing size={17} /></span><span><small>{item.kind}</small><strong>{item.title}</strong><p>{item.detail}</p></span><time>{item.time}</time></button>)}</Panel></div></Localized>;
}

export function AccountView() {
  return <Localized><div className="page narrow-page"><PageHeading eyebrow="ACCOUNT & ACCESS" title="계정과 보안" description="로그인 수단과 서버 실행 확인 정책을 관리합니다." />
    <div className="settings-grid"><Panel title="프로필"><ListRow icon={UserRound} title="김전략" detail="kyoungcheul.min@gmail.com" /><ListRow icon={Mail} title="이메일 로그인" detail="인증 완료" end={<Status tone="positive">연결됨</Status>} /></Panel><Panel title="접근 보안"><ListRow icon={KeyRound} title="소셜 로그인" detail="Google 계정" end={<Status tone="positive">연결됨</Status>} /><ListRow icon={LockKeyhole} title="동시 접속" detail="한 번에 하나의 세션만 허용" /></Panel><Panel className="span-2" title="무소속 봇 계속 실행"><div className="renew-card"><div><strong>Atlas 07</strong><span>다음 확인 기한 · 2026.08.10 10:42 ET</span></div><Button kind="primary">30일 연장</Button></div><HelpNote>로그인이나 화면 조회만으로 기한은 연장되지 않습니다. 서버가 버튼 요청을 접수한 시각을 기준으로 계산합니다.</HelpNote></Panel></div>
  </div></Localized>;
}

export function AdminView() {
  return <Localized><div className="page"><PageHeading eyebrow="RBAC · OPERATOR" title="운영 관리" description="권한이 있는 운영자만 데이터 품질과 시장 이벤트 반영 작업을 처리합니다." actions={<Status tone="neutral">OPERATOR</Status>} />
    <div className="admin-grid"><Panel title="처리 대기" subtitle="오늘 확인할 운영 사건"><ListRow icon={Database} title="시장 데이터 품질 사건 2건" detail="SPY 1m 누락 · AAPL adjusted 갱신" /><ListRow icon={Wrench} title="기업행동 검토 1건" detail="액면분할 예정 정보 · 운영자 확인 필요" /><ListRow icon={ServerCog} title="수집 파이프라인" detail="07:00 ET 실행 완료" end={<Status tone="positive">정상</Status>} /></Panel><Panel title="권한 범위" subtitle="상위 권한자가 하위 권한을 부여"><div className="permission-list"><span><ShieldCheck size={16} />데이터 카탈로그 관리</span><span><ShieldCheck size={16} />시장 이벤트 검토</span><span><ShieldCheck size={16} />운영자 권한 부여</span></div></Panel><Panel className="span-2" title="시장 이벤트 반영 흐름" subtitle="AI 조사 결과는 자동 투자 판단이 아니라 운영자용 자료입니다"><div className="process-strip"><span>외부 정보 조사</span><i>→</i><span>운영자 검토</span><i>→</i><span>Admin MCP 승인</span><i>→</i><span>이벤트 트리거 반영</span></div><HelpNote>제품 내부 전략 평가에는 AI를 사용하지 않습니다.</HelpNote></Panel></div>
  </div></Localized>;
}
