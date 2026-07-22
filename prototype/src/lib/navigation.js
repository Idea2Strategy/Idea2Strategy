import { Bell, Bot, Building2, FlaskConical, LayoutGrid, ShieldCheck, Users } from 'lucide-react';

export const navItems = [
  { id: 'strategy', label: '전략', icon: LayoutGrid },
  { id: 'bots', label: '봇', icon: Bot },
  { id: 'backtest', label: '백테스트', icon: FlaskConical },
  { id: 'rooms', label: '방', icon: Users },
  { id: 'notifications', label: '알림', icon: Bell, count: 2 },
];

export const utilityItems = [
  { id: 'account', label: '계정', icon: ShieldCheck },
  { id: 'admin', label: '관리자', icon: Building2 },
];

export function variantFromLocation(pathname = '') {
  return pathname.includes('terminal') ? 'terminal' : 'balanced';
}
