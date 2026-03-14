
</main>
</div>
<script>
document.querySelectorAll('form').forEach(f => {
    f.addEventListener('submit', function() {
        const btn = this.querySelector('button[type="submit"]');
        if (btn && !btn.classList.contains('loading')) btn.classList.add('loading');
    });
});
</script>
</body>
</html>
