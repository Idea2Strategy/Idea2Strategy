# Strategy editor UI direction

## Status

User-confirmed product-discovery proposal. This document records UI meaning only; protected integration still requires live Git review and it does not authorize frontend implementation or removal of the existing submodule.

## Existing UI boundary

The current `ui/` submodule is retired as a reference, seed, and baseline input. A later reviewed repository change will remove it. New UI proposals start from the canonical product policies and the interaction requirements below.

## Basic editor

Basic uses Scratch-style blocks that interlock directly without connector lines. A buy strategy container and a sell strategy container wrap their respective inner blocks and remain recognizable by label, enclosing shape, and distinct color; buy uses a red family as the current direction. Inner blocks show only the indicator, operator, editable value, and other text required for manipulation.

Hovering a completed block group displays a rule-based natural-language fragment beside each corresponding block. Reading those fragments in order forms a strategy sentence for review without changing or generating the strategy.

Basic offers separate buy and sell templates. Indicator search can return simple upward/downward-condition structures as well as structures based on widely known or officially used indicator theories. Security, period, threshold, ratio, budget, risk, and other material values remain unset.

## Pro editor

Pro uses a left-to-right typed node graph. A node may expose two or more semantic outputs such as true and false. The catalog may favor fewer general nodes with richer parameters and output ports; the exact catalog remains later work.

Compatible nodes and ports are enabled during connection work and incompatible targets are disabled. When the user releases a connection over empty canvas, a categorized picker opens at that pointer location and contains nodes compatible with the originating output. Individual explanations for disabled targets are not required.

Pro supports both an empty canvas and structural templates drawn from widely known financial-engineering, quantitative, parallel, and pair-trading patterns. All material values remain unset.

## Legal and product boundary

Templates describe structures factually. They do not recommend securities, values, allocations, timing, risk levels, expected returns, or strategy quality, and they do not use labels such as recommended, safe, superior, or profitable.

## Deferred visual decisions

Exact colors, spacing, panel placement, density, typography, responsive boundaries, pointer behavior at viewport edges, keyboard and assistive alternatives, and the exact node and template catalogs require comparison in the new editable UI workspace.
