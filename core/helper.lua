-- Helper

function draw_item_sprite(sprite, x, y, scale, alpha)
    gm.draw_sprite_ext(sprite, 0, x, y, scale or 1, scale or 1, 0, Color.WHITE, alpha or 1)
end