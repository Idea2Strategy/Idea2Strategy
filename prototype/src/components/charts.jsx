function pointsFor(values, width, height, pad = 8) {
  const min = Math.min(...values);
  const max = Math.max(...values);
  const range = max - min || 1;
  return values.map((value, index) => [pad + (index / (values.length - 1)) * (width - pad * 2), height - pad - ((value - min) / range) * (height - pad * 2)]);
}

export function AreaChart({ values, height = 220, label = '자산 변화 차트' }) {
  const width = 760;
  const points = pointsFor(values, width, height, 12);
  const line = points.map(([x, y]) => `${x},${y}`).join(' ');
  const area = `12,${height - 12} ${line} ${width - 12},${height - 12}`;
  return (
    <div className="chart-shell" role="img" aria-label={label}>
      <svg viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none">
        <defs><linearGradient id="area-fill" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="var(--accent)" stopOpacity=".28" /><stop offset="1" stopColor="var(--accent)" stopOpacity="0" /></linearGradient></defs>
        {[0.2, 0.4, 0.6, 0.8].map((n) => <line key={n} x1="0" x2={width} y1={height * n} y2={height * n} className="chart-grid" />)}
        <polygon points={area} fill="url(#area-fill)" />
        <polyline points={line} fill="none" className="chart-line" vectorEffect="non-scaling-stroke" />
        <circle cx={points.at(-1)[0]} cy={points.at(-1)[1]} r="5" className="chart-point" vectorEffect="non-scaling-stroke" />
      </svg>
    </div>
  );
}

export function MiniSpark({ values, negative = false }) {
  const line = pointsFor(values, 110, 34, 3).map(([x, y]) => `${x},${y}`).join(' ');
  return <svg className={`mini-spark ${negative ? 'negative' : ''}`} viewBox="0 0 110 34" aria-hidden="true"><polyline points={line} fill="none" vectorEffect="non-scaling-stroke" /></svg>;
}

export function BarList({ items }) {
  const max = Math.max(...items.map((item) => item.value));
  return <div className="bar-list">{items.map((item) => <div className="bar-row" key={item.label}><div><span>{item.label}</span><strong>{item.value}</strong></div><div className="bar-track"><i style={{ width: `${(item.value / max) * 100}%` }} /></div></div>)}</div>;
}
