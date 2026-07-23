import { fireEvent, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, test } from 'vitest';
import { App } from './App.jsx';

describe('Signal product UI', () => {
  beforeEach(() => window.localStorage.clear());

  test('switches the product between Korean and English and remembers the choice', async () => {
    const user = userEvent.setup();
    const { unmount } = render(<App />);

    await user.selectOptions(screen.getByRole('combobox', { name: '언어 선택' }), 'en');
    expect(screen.getByRole('heading', { name: 'Strategies' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'New strategy' })).toBeInTheDocument();
    expect(document.documentElement).toHaveAttribute('lang', 'en');
    await user.click(screen.getByRole('button', { name: 'Bots' }));
    expect(screen.getByRole('heading', { name: 'Bot operations' })).toBeInTheDocument();

    unmount();
    render(<App />);
    expect(screen.getByRole('combobox', { name: 'Language' })).toHaveValue('en');
    expect(screen.getByRole('heading', { name: 'Strategies' })).toBeInTheDocument();
  });

  test('uses one heading composition and one active navigation rule on every primary page', async () => {
    const user = userEvent.setup();
    render(<App />);

    for (const [navigation, heading] of [
      ['전략', '전략'],
      ['봇', '봇 운영 센터'],
      ['백테스트', '자동 백테스트'],
      ['Competition', 'Competition'],
    ]) {
      await user.click(screen.getByRole('button', { name: navigation }));
      expect(screen.getByRole('heading', { name: heading }).closest('.page-heading')).not.toBeNull();
      const activeItems = document.querySelectorAll('.signal-product-nav > nav button.active');
      expect(activeItems).toHaveLength(1);
      expect(activeItems[0]).toHaveAccessibleName(navigation);
    }
  });

  test.each(['balanced', 'terminal'])('uses the official I2S logo in the %s navigation', (variant) => {
    render(<App initialVariant={variant} />);
    const logo = screen.getByRole('img', { name: 'Idea2Strategy' });
    expect(logo).toHaveAttribute('src', expect.stringContaining('i2s-logo.svg'));
  });

  test.each(['balanced', 'terminal'])('resolves the legacy %s entry to the shared Signal product UI', (variant) => {
    render(<App initialVariant={variant} />);
    for (const name of ['전략', '봇', '백테스트', 'Competition']) expect(screen.getByRole('button', { name })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '알림' })).toBeInTheDocument();
    expect(screen.getByTestId('app-shell')).toHaveAttribute('data-variant', 'signal');
    expect(screen.queryByText('TERMINAL / PULSE')).not.toBeInTheDocument();
    expect(screen.queryByText('BALANCED / SIGNAL')).not.toBeInTheDocument();
  });

  test('uses Signal Studio as the balanced visual baseline', () => {
    render(<App initialVariant="balanced" />);

    expect(screen.getByTestId('app-shell')).toHaveAttribute('data-design', 'signal-studio');
    expect(screen.getByTestId('app-shell')).toHaveAttribute('data-theme', 'dark');
  });

  test('switches theme without losing the active page', async () => {
    const user = userEvent.setup();
    render(<App initialVariant="balanced" />);
    await user.click(screen.getByRole('button', { name: '봇' }));
    await user.click(screen.getByRole('button', { name: '라이트 모드' }));
    expect(screen.getByRole('heading', { name: '봇 운영 센터' })).toBeInTheDocument();
    expect(screen.getByTestId('app-shell')).toHaveAttribute('data-theme', 'light');
    expect(screen.queryByRole('button', { name: '터미널형 보기' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: '균형형 보기' })).not.toBeInTheDocument();
  });

  test('shows the complete buy rule when the Basic buy group is clicked', async () => {
    const user = userEvent.setup();
    render(<App initialVariant="balanced" />);
    await user.click(screen.getByRole('button', { name: '새 전략' }));
    await user.click(screen.getByRole('button', { name: 'Basic으로 시작' }));
    await user.hover(screen.getByTestId('buy-rsi-block'));
    expect(screen.queryByText(/새로운 1분봉/)).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: '매수 전략 자연어 설명' }));
    const explanation = screen.getByRole('tooltip');
    expect(explanation).toHaveTextContent('새로운 1분봉');
    expect(explanation).toHaveTextContent('RSI가 30 아래');
    expect(explanation).toHaveTextContent('25%');
    expect(explanation).toHaveTextContent('시장가 매수 후보');
  });

  test('opens a categorized compatible-node picker where a Pro connection is released', async () => {
    const user = userEvent.setup();
    render(<App initialVariant="terminal" />);
    await user.click(screen.getByRole('button', { name: '새 전략' }));
    await user.click(screen.getByRole('button', { name: 'Pro로 시작' }));
    fireEvent.pointerUp(screen.getByTestId('true-output'), { clientX: 438, clientY: 276 });
    const picker = screen.getByRole('dialog', { name: '호환 노드 선택' });
    expect(picker).toHaveStyle({ left: '438px', top: '276px' });
    expect(screen.getByText('조건 · 비교')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '포지션 확인' })).toBeEnabled();
  });

  test.each(['balanced', 'terminal'])('uses one Signal horizontal menu for the legacy %s entry', (variant) => {
    render(<App initialVariant={variant} />);
    const signalMenu = screen.getByRole('navigation', { name: 'Signal 주요 메뉴' });
    expect(signalMenu).toHaveAttribute('data-orientation', 'horizontal');
    expect(screen.queryByTestId('primary-sidebar')).not.toBeInTheDocument();
    expect(screen.getByRole('img', { name: 'Idea2Strategy' }).parentElement).toHaveTextContent('IDEA2STRATEGY');
    expect(screen.queryByRole('button', { name: '메뉴 접기' })).not.toBeInTheDocument();
    expect(screen.queryByText('SIMULATION OS')).not.toBeInTheDocument();
  });

  test('searches and filters balanced strategies', async () => {
    const user = userEvent.setup();
    render(<App initialVariant="balanced" />);

    await user.type(screen.getByRole('searchbox', { name: '전략 검색' }), 'Pair');
    expect(screen.getByText('Pair Spread Monitor')).toBeInTheDocument();
    expect(screen.queryByText('Opening Range Flow')).not.toBeInTheDocument();

    await user.clear(screen.getByRole('searchbox', { name: '전략 검색' }));
    await user.click(screen.getByRole('button', { name: 'Pro 전략만 보기' }));
    expect(screen.getByText('Pair Spread Monitor')).toBeInTheDocument();
    expect(screen.getByText('Volume Regime Draft')).toBeInTheDocument();
    expect(screen.queryByText('Opening Range Flow')).not.toBeInTheDocument();
  });

  test('removes blocks and copy actions from the strategy home and imports only during creation', async () => {
    const user = userEvent.setup();
    render(<App initialVariant="balanced" />);

    expect(screen.queryByRole('searchbox', { name: '블록 검색' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Opening Range Flow 복사' })).not.toBeInTheDocument();
    expect(screen.queryByText('7 blocks')).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: '새 전략' }));
    expect(screen.getByRole('dialog', { name: '새 전략 선택' })).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: '기존 전략 가져오기' }));
    expect(screen.getByRole('button', { name: 'Opening Range Flow 가져오기' })).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Opening Range Flow 가져오기' }));
    expect(screen.getByRole('heading', { name: 'Basic 전략 편집기' })).toBeInTheDocument();
  });

  test('uses compact strategy counts without a secondary block panel', () => {
    render(<App initialVariant="balanced" />);

    expect(screen.queryByLabelText('전략 요약')).not.toBeInTheDocument();
    expect(screen.getByTestId('strategy-counts')).toHaveTextContent('전체 3');
    expect(screen.queryByRole('heading', { name: '블록' })).not.toBeInTheDocument();
  });

  test('replaces the global market strip with configurable symbols and topbar notifications', async () => {
    const user = userEvent.setup();
    render(<App initialVariant="balanced" />);

    expect(screen.queryByText('MARKET')).not.toBeInTheDocument();
    expect(screen.queryByText('S&P 500')).not.toBeInTheDocument();
    expect(screen.queryByTestId('primary-sidebar')).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: '관심종목 설정' }));
    expect(screen.getByRole('dialog', { name: '관심종목' })).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'NVDA 추가' }));
    expect(screen.getByText('NVDA')).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: '알림' }));
    expect(screen.getByRole('dialog', { name: '최근 알림' })).toBeInTheDocument();
  });

  test('uses unfinished terminology instead of input-needed terminology', () => {
    render(<App initialVariant="balanced" />);
    expect(screen.getByText('미완성')).toBeInTheDocument();
    expect(screen.queryByText('입력 필요')).not.toBeInTheDocument();
  });

  test('rebuilds Competition as official cards and a searchable filtered list', async () => {
    const user = userEvent.setup();
    render(<App initialVariant="balanced" />);
    await user.click(screen.getByRole('button', { name: 'Competition' }));

    expect(screen.getByRole('heading', { name: 'Competition' })).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: '공식 Competition' })).toBeInTheDocument();
    const search = screen.getByRole('searchbox', { name: 'Competition 검색' });
    await user.type(search, 'ETF');
    expect(screen.getByText('ETF Discipline')).toBeInTheDocument();
    expect(screen.queryByText('Momentum Lab')).not.toBeInTheDocument();

    await user.clear(search);
    await user.click(screen.getByRole('button', { name: 'Momentum Lab 순위 펼치기' }));
    expect(screen.getByText('Room Beta')).toBeInTheDocument();
  });
});
