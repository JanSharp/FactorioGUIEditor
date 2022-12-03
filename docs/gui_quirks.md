
Making a gui element stretchable but then also setting a fixed size for that dimension behaves weirdly.
For example:
The particular case I ran into was having a vertical flow with 2 horizontal flows as children where the first horizontal flow had a fixed height. Note that horizontal flows are vertically stretchable by default. This caused the second flow to only take up half of the remaining space. Not setting a fixed size removed the problem, setting vertically stretchable to false also fixed the problem.

gui elements that consist of multiple elements internally only raise click events for the root element. This is especially noticeable with frames - their inner flow - and similarly scroll panes. In the case of scroll panes it's also noticeable when clicking the scroll bars.
For example:
This is relevant for the window manager because it has to handle all click events and bring the the invisible frames which are on top of a window, well, back to the top. It also has to know which window is currently focused, which changes both the title color and affects context aware key binds. So I have to remember to add basic flows as children of frames and scroll panes to get click events for those.

putting a script text box just in an empty window (frame, basically) for example makes the scroll pane that is in the script text box no longer work, as in the root frame of the script text box is not squashing, neither is the scroll pane inside of it. If you put the script text box inside of another scroll pane then the inner scroll pane suddenly starts working. basically:
frame => frame => frame => scroll pane => weird combination of too large elements => doesn't squash
frame => frame => scroll pane => frame => scroll pane => weird combination of too large elements => does squash!
