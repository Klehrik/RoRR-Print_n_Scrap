-- Helper

function draw_item_sprite(sprite, x, y, scale, alpha)
    gm.draw_sprite_ext(sprite, 0, x, y, scale or 1.0, scale or 1.0, 0.0, Color.WHITE, alpha or 1.0)
end


function free_actor(actor)
    -- Reset actor activity
    actor.activity = 0.0
    actor.activity_free = true
    actor.activity_move_factor = 1.0
    actor.activity_type = 0.0
end