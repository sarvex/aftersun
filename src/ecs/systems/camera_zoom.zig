const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;
const atlas = game.state.atlas;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {

    if (game.state.controls.mouse.scroll.up() and game.state.camera.zoom < game.state.camera.maxZoom() and game.state.camera.zoom_progress <= 0.0) {
        game.state.camera.zoom_progress = 0.0;
        game.state.camera.zoom_prev = game.state.camera.zoom;
        game.state.camera.zoom_next = @round(game.state.camera.zoom) + 1.0;
    }

    if (game.state.controls.mouse.scroll.down() and game.state.camera.zoom > game.state.camera.minZoom() and game.state.camera.zoom_progress <= 0.0) {
        game.state.camera.zoom_progress = 0.0;
        game.state.camera.zoom_prev = game.state.camera.zoom;
        game.state.camera.zoom_next = @round(game.state.camera.zoom) - 1.0;
    }

    if (game.state.camera.zoom_progress >= 1.0) {
        game.state.camera.zoom_progress = 0.0;
        game.state.camera.zoom = game.state.camera.zoom_next;
        game.state.camera.zoom_prev = game.state.camera.zoom;
    } else {
        game.state.camera.zoom_progress += it.delta_time * game.state.camera.zoom;
        game.state.camera.zoom = game.math.lerp(game.state.camera.zoom_prev, game.state.camera.zoom_next, std.math.clamp(game.state.camera.zoom_progress, 0.0, 1.0));
    }
}