/**
 * LernHub — Water-drop cursor linger effect
 * Spawns a red-tinted drop when cursor pauses for ~1s
 */
(function() {
    // Disable on touch devices
    if (window.matchMedia('(hover: none)').matches) return;

    const overlay = document.createElement('div');
    overlay.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;pointer-events:none;z-index:9998;overflow:hidden;';
    document.body.appendChild(overlay);

    let lingerTimer = null;
    let lastX = 0, lastY = 0;

    document.addEventListener('mousemove', function(e) {
        lastX = e.clientX;
        lastY = e.clientY;

        if (lingerTimer) clearTimeout(lingerTimer);

        lingerTimer = setTimeout(function() {
            spawnDrop(lastX, lastY);
        }, 1000);
    });

    function spawnDrop(x, y) {
        const drop = document.createElement('div');
        drop.className = 'cursor-drop';
        drop.style.left = (x - 20) + 'px';
        drop.style.top = (y - 20) + 'px';
        overlay.appendChild(drop);

        // After grow phase (0.8s), trigger drip
        setTimeout(function() {
            drop.classList.add('cursor-drop-drip');
        }, 800);

        // Cleanup after full animation
        setTimeout(function() {
            if (drop.parentNode) drop.parentNode.removeChild(drop);
        }, 2800);
    }
})();
