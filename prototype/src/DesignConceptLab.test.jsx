import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, test } from 'vitest';
import { DesignConceptLab } from './views/DesignConceptLab.jsx';

describe('DesignConceptLab', () => {
  test('compares three concepts across main and strategy pages', async () => {
    const user = userEvent.setup();
    render(<DesignConceptLab />);

    expect(screen.getByTestId('design-concept')).toHaveAttribute('data-concept', 'atlas');
    expect(screen.getByRole('heading', { name: /오늘의 투자 흐름/ })).toBeInTheDocument();

    await user.click(within(screen.getByRole('group', { name: '페이지 선택' })).getByRole('button', { name: '전략 페이지 보기' }));
    expect(screen.getByRole('searchbox', { name: '전략 검색' })).toBeInTheDocument();
    expect(screen.queryByText('블록 라이브러리')).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: /B · Flow Canvas/ }));
    expect(screen.getByTestId('design-concept')).toHaveAttribute('data-concept', 'flow');
    expect(screen.getByText('전략 캔버스')).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: /C · Signal Studio/ }));
    expect(screen.getByTestId('design-concept')).toHaveAttribute('data-concept', 'signal');
    expect(screen.getByText('STRATEGY DESK')).toBeInTheDocument();
  });

  test('filters the strategy examples', async () => {
    const user = userEvent.setup();
    render(<DesignConceptLab />);

    await user.click(within(screen.getByRole('group', { name: '페이지 선택' })).getByRole('button', { name: '전략 페이지 보기' }));
    await user.type(screen.getByRole('searchbox', { name: '전략 검색' }), '나스닥');

    expect(screen.getByText('나스닥 추세 추종')).toBeInTheDocument();
    expect(screen.queryByText('배당 성장 리밸런싱')).not.toBeInTheDocument();
  });

  test('keeps an independent color palette for each concept', async () => {
    const user = userEvent.setup();
    render(<DesignConceptLab />);

    expect(screen.getByTestId('design-concept')).toHaveAttribute('data-palette', 'mint');
    await user.click(screen.getByRole('button', { name: 'Ocean 색상' }));
    expect(screen.getByTestId('design-concept')).toHaveAttribute('data-palette', 'ocean');

    await user.click(screen.getByRole('button', { name: /B · Flow Canvas/ }));
    expect(screen.getByTestId('design-concept')).toHaveAttribute('data-palette', 'sage');
    await user.click(screen.getByRole('button', { name: 'Lavender 색상' }));
    expect(screen.getByTestId('design-concept')).toHaveAttribute('data-palette', 'lavender');

    await user.click(screen.getByRole('button', { name: /C · Signal Studio/ }));
    await user.click(screen.getByRole('button', { name: 'Light Mint 색상' }));
    expect(screen.getByTestId('design-concept')).toHaveAttribute('data-palette', 'light-mint');
  });

  test('keeps each Atlas strategy in a single five-column table row', async () => {
    const user = userEvent.setup();
    render(<DesignConceptLab />);

    await user.click(within(screen.getByRole('group', { name: '페이지 선택' })).getByRole('button', { name: '전략 페이지 보기' }));
    const row = screen.getByRole('button', { name: /나스닥 추세 추종/ });

    expect(row).toHaveClass('atlas-row');
    expect(row.children).toHaveLength(5);
    expect(row.querySelector('.atlas-name-cell')).toBeInTheDocument();
  });

  test('adds Ledger and Orbit as complete main and strategy concepts', async () => {
    const user = userEvent.setup();
    render(<DesignConceptLab />);
    const pageTabs = screen.getByRole('group', { name: '페이지 선택' });

    await user.click(screen.getByRole('button', { name: /D · Ledger Mono/ }));
    expect(screen.getByRole('heading', { name: /숫자는 차분하게/ })).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Cobalt 색상' }));
    expect(screen.getByTestId('design-concept')).toHaveAttribute('data-palette', 'cobalt');
    await user.click(within(pageTabs).getByRole('button', { name: '전략 페이지 보기' }));
    expect(screen.getByText('STRATEGY REGISTER')).toBeInTheDocument();
    expect(screen.getByRole('searchbox', { name: '전략 검색' })).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: /E · Orbit Glass/ }));
    expect(screen.getByText('전략 오비트')).toBeInTheDocument();
    await user.click(within(pageTabs).getByRole('button', { name: '메인 페이지 보기' }));
    expect(screen.getByRole('heading', { name: /전략이 궤도에.*있습니다/ })).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Violet 색상' }));
    expect(screen.getByTestId('design-concept')).toHaveAttribute('data-palette', 'violet');
  });

  test('extends Flow, Signal, and Orbit through every menu page and strategy creation', async () => {
    const user = userEvent.setup();
    render(<DesignConceptLab />);

    for (const concept of [
      { button: /B · Flow Canvas/, nav: 'Flow 메뉴' },
      { button: /C · Signal Studio/, nav: 'Signal 메뉴' },
      { button: /E · Orbit Glass/, nav: 'Orbit 메뉴' },
    ]) {
      await user.click(screen.getByRole('button', { name: concept.button }));
      const nav = screen.getByRole('navigation', { name: concept.nav });

      await user.click(within(nav).getByRole('button', { name: /봇|BOTS|Bots/ }));
      expect(screen.getByRole('heading', { name: '봇 운영' })).toBeInTheDocument();

      await user.click(within(nav).getByRole('button', { name: /백테스트|BACKTEST|Backtest/ }));
      expect(screen.getByRole('heading', { name: '백테스트 분석' })).toBeInTheDocument();

      await user.click(within(nav).getByRole('button', { name: /Competition|COMPETITION/ }));
      expect(screen.getByRole('heading', { name: 'Competition' })).toBeInTheDocument();

      await user.click(within(nav).getByRole('button', { name: /전략|STRATEGIES|Strategy/ }));
      await user.click(screen.getByRole('button', { name: /새 전략|NEW STRATEGY/ }));
      expect(screen.getByRole('heading', { name: '새 전략 만들기' })).toBeInTheDocument();
      expect(screen.getByText('매수 전략 · 필수')).toBeInTheDocument();
      expect(screen.getByText('매도 전략 · 선택')).toBeInTheDocument();
    }
  });

  test('replaces F with the referenced Core Interface language', async () => {
    const user = userEvent.setup();
    render(<DesignConceptLab />);

    await user.click(screen.getByRole('button', { name: /F · Core Interface/ }));
    expect(screen.getByRole('heading', { name: /오늘의 전략 신호를.*한 화면에/ })).toBeInTheDocument();
    expect(screen.getByText('REAL-TIME · ENCRYPTED')).toBeInTheDocument();
    expect(screen.getByText('TIMELINE')).toBeInTheDocument();
    expect(screen.getByText('PENDING ACTIONS')).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Violet 색상' }));
    expect(screen.getByTestId('design-concept')).toHaveAttribute('data-palette', 'core-violet');

    await user.click(within(screen.getByRole('group', { name: '페이지 선택' })).getByRole('button', { name: '전략 페이지 보기' }));
    expect(screen.getByText('STRATEGY INTERFACE')).toBeInTheDocument();
    expect(screen.getByRole('searchbox', { name: '전략 검색' })).toBeInTheDocument();
  });
});
