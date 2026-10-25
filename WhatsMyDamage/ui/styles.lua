--[[
    WhatsMyDamage - ui/styles.lua

    Bar styles. Each draws one bar from x1 to x2 (the filled part ends at
    x1 + (x2 - x1) * frac) on the window's draw list:

      details    Details! default: vertical shading, a light top edge and a
                 dark bottom edge (the "textured" look)
      flat       one solid color
      gradient   dark on the left, full color at the end
      glass      see-through color with a shine on the top half
      rounded    Gradient colors with softly rounded corners (1.0.1, replaces striped)
      neon       dark inside, glowing colored outline and end
      fade       full color fading out toward the end
      pill       rounded ends with a highlight
      underline  a faint fill with a bold line along the bottom
]]

require('common');
local imgui = require('imgui');

local styles = {};

styles.LIST = {
    { key = 'details', label = 'Details', tip = 'Like Details!: shaded top to bottom, light top edge, dark bottom edge.' },
    { key = 'flat', label = 'Flat', tip = 'One solid color.' },
    { key = 'gradient', label = 'Gradient', tip = 'Darker at the start, full color at the end of the bar.' },
    { key = 'glass', label = 'Glass', tip = 'See-through color with a shine across the top half.' },
    { key = 'rounded', label = 'Rounded', tip = 'Like Gradient, with softly rounded corners (less round than Pill).' },
    { key = 'neon', label = 'Neon', tip = 'Dark inside with a glowing colored outline and end.' },
    { key = 'fade', label = 'Fade', tip = 'Full color that fades out toward the end of the bar.' },
    { key = 'pill', label = 'Pill', tip = 'Rounded ends with a soft highlight.' },
    { key = 'underline', label = 'Underline', tip = 'A faint fill with a bold colored line along the bottom.' },
};

local function U32(c) return imgui.GetColorU32(c); end
local function shade(c, k, a) return { c[1] * k, c[2] * k, c[3] * k, a or c[4] or 1 }; end
local function tint(c, k, a)
    return { c[1] + (1 - c[1]) * k, c[2] + (1 - c[2]) * k, c[3] + (1 - c[3]) * k, a or c[4] or 1 };
end
local function with_a(c, a) return { c[1], c[2], c[3], a }; end

-- opts: { alpha (0-1), rounding (px), track (color or nil), anim (bool) }
function styles.draw(dl, style, x1, y1, x2, y2, frac, color, opts)
    opts = opts or {};
    if style == 'striped' then style = 'rounded'; end   -- 1.0.1: Striped was replaced by Rounded
    local alpha = tonumber(opts.alpha) or 1;
    local r = tonumber(opts.rounding) or 0;
    local h = y2 - y1;
    -- Rounded: corners about a quarter of the bar height (Pill uses half).
    if style == 'rounded' then r = math.max(r, math.min(6, math.max(2, h * 0.26))); end
    frac = math.max(0, math.min(1, frac or 0));
    local xe = x1 + (x2 - x1) * frac;
    local c = with_a(color, (color[4] or 1) * alpha);
    local ca = c[4];

    -- The empty part behind the bar.
    if opts.track ~= nil and (opts.track[4] or 0) > 0 then
        dl:AddRectFilled({ x1, y1 }, { x2, y2 }, U32(opts.track), (style == 'pill') and h / 2 or math.min(r, h / 2));
    end
    if xe - x1 < 0.5 then return; end

    if style == 'flat' then
        dl:AddRectFilled({ x1, y1 }, { xe, y2 }, U32(c), r);

    elseif style == 'gradient' then
        local left, right = shade(c, 0.40, ca), c;
        dl:AddRectFilledMultiColor({ x1, y1 }, { xe, y2 }, U32(left), U32(right), U32(right), U32(left));

    elseif style == 'glass' then
        dl:AddRectFilled({ x1, y1 }, { xe, y2 }, U32(with_a(c, ca * 0.50)), r);
        dl:AddRectFilledMultiColor({ x1, y1 }, { xe, y1 + h * 0.5 },
            U32({ 1, 1, 1, 0.22 * ca }), U32({ 1, 1, 1, 0.22 * ca }), U32({ 1, 1, 1, 0.04 * ca }), U32({ 1, 1, 1, 0.04 * ca }));
        dl:AddLine({ x1, y1 + 0.5 }, { xe, y1 + 0.5 }, U32(tint(c, 0.5, ca)), 1);
        dl:AddLine({ xe - 1, y1 }, { xe - 1, y2 }, U32(tint(c, 0.6, ca)), 2);

    elseif style == 'rounded' then
        -- The Gradient colors (dark at the start, full color at the end) with
        -- softly rounded corners. The gradient fill can't round its corners,
        -- so it runs between two rounded end caps in the matching colors.
        local w = math.max(xe - x1, r * 2 + 2);
        local xr = x1 + w;
        local rr = math.min(r, h / 2);
        local left, right = shade(c, 0.40, ca), c;
        local cap = rr + 1;
        dl:AddRectFilled({ x1, y1 }, { x1 + cap, y2 }, U32(left), rr, ImDrawFlags_RoundCornersLeft or 0x50);
        dl:AddRectFilled({ xr - cap, y1 }, { xr, y2 }, U32(right), rr, ImDrawFlags_RoundCornersRight or 0xA0);
        if xr - rr > x1 + rr then
            dl:AddRectFilledMultiColor({ x1 + rr, y1 }, { xr - rr, y2 }, U32(left), U32(right), U32(right), U32(left));
        end

    elseif style == 'neon' then
        dl:AddRectFilled({ x1, y1 }, { xe, y2 }, U32(shade(c, 0.28, ca * 0.85)), r);
        -- glow
        for i = 3, 1, -1 do
            dl:AddRect({ x1 - i, y1 - i }, { xe + i, y2 + i }, U32(with_a(c, ca * 0.10 * (4 - i))), r + i, 0, 1);
        end
        dl:AddRect({ x1, y1 }, { xe, y2 }, U32(tint(c, 0.15, ca)), r, 0, 1.5);
        dl:AddRectFilled({ xe - 3, y1 + 1 }, { xe - 1, y2 - 1 }, U32(tint(c, 0.55, ca)), 1);

    elseif style == 'fade' then
        local a0, a1 = c, with_a(c, 0);
        dl:AddRectFilledMultiColor({ x1, y1 }, { xe, y2 }, U32(a0), U32(a1), U32(a1), U32(a0));
        dl:AddRectFilled({ x1, y1 }, { x1 + 3, y2 }, U32(tint(c, 0.25, ca)), 0);

    elseif style == 'pill' then
        local rr = h / 2;
        local w = math.max(h, xe - x1);
        dl:AddRectFilled({ x1, y1 }, { x1 + w, y2 }, U32(c), rr);
        dl:AddRectFilled({ x1 + rr * 0.5, y1 + 1.5 }, { x1 + w - rr * 0.5, y1 + h * 0.42 }, U32({ 1, 1, 1, 0.16 * ca }), rr * 0.6);

    elseif style == 'underline' then
        dl:AddRectFilled({ x1, y1 }, { xe, y2 }, U32(with_a(c, ca * 0.18)), r);
        local lh = math.max(2, h * 0.14);
        dl:AddRectFilled({ x1, y2 - lh }, { xe, y2 }, U32(c), 0);

    else -- 'details'
        local top, bottom = tint(c, 0.10, ca), shade(c, 0.62, ca);
        dl:AddRectFilledMultiColor({ x1, y1 }, { xe, y2 }, U32(top), U32(top), U32(bottom), U32(bottom));
        dl:AddLine({ x1, y1 + 0.5 }, { xe, y1 + 0.5 }, U32({ 1, 1, 1, 0.20 * ca }), 1);
        dl:AddLine({ x1, y2 - 0.5 }, { xe, y2 - 0.5 }, U32({ 0, 0, 0, 0.45 * ca }), 1);
        dl:AddRectFilledMultiColor({ x1, y1 }, { xe, y1 + h * 0.45 },
            U32({ 1, 1, 1, 0.07 * ca }), U32({ 1, 1, 1, 0.07 * ca }), U32({ 1, 1, 1, 0 }), U32({ 1, 1, 1, 0 }));
    end
end

return styles;
