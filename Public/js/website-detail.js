const websiteId = window.location.pathname.split('/')[2];

// Collapsible Embed Section
const embedToggle = document.getElementById('embedToggle');
const embedContent = document.getElementById('embedContent');

embedToggle.onclick = () => {
    embedToggle.classList.toggle('collapsed');
    embedContent.classList.toggle('collapsed');
};

// Copy to clipboard
function copyToClipboard(elementId) {
    const element = document.getElementById(elementId);
    const text = element.textContent;
    navigator.clipboard.writeText(text).then(() => {
        const btn = event.target;
        const originalText = btn.textContent;
        btn.textContent = 'Copied!';
        setTimeout(() => btn.textContent = originalText, 2000);
    });
}

// Edit website
document.getElementById('editWebsiteBtn').onclick = () => {
    document.getElementById('editWebsiteModal').style.display = 'flex';
};

document.getElementById('cancelEditBtn').onclick = () => {
    document.getElementById('editWebsiteModal').style.display = 'none';
};

document.getElementById('editWebsiteForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const name = document.getElementById('editName').value;
    const domain = document.getElementById('editDomain').value;
    const errorDiv = document.getElementById('editError');

    try {
        const response = await fetch(`/websites/${websiteId}`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name, domain })
        });

        if (response.ok) {
            window.location.reload();
        } else {
            const error = await response.json();
            errorDiv.textContent = error.reason || 'Failed to update website';
        }
    } catch (err) {
        errorDiv.textContent = 'Network error';
    }
});

// Archive website
document.getElementById('archiveWebsiteBtn').onclick = async () => {
    try {
        const response = await fetch(`/websites/${websiteId}/archive`, {
            method: 'POST'
        });

        if (response.ok) {
            window.location.href = '/dashboard';
        } else {
            alert('Failed to archive website');
        }
    } catch (err) {
        alert('Network error');
    }
};

// Add prompt
document.getElementById('addPromptBtn').onclick = () => {
    document.getElementById('addPromptModal').style.display = 'flex';
};

document.getElementById('cancelPromptBtn').onclick = () => {
    document.getElementById('addPromptModal').style.display = 'none';
};

document.getElementById('addPromptForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const prompt = document.getElementById('prompt').value;
    const isActive = document.getElementById('isActive').checked;
    const errorDiv = document.getElementById('promptError');

    try {
        const response = await fetch(`/websites/${websiteId}/moderation-prompts`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ prompt, isActive })
        });

        if (response.ok) {
            window.location.reload();
        } else {
            const error = await response.json();
            errorDiv.textContent = error.reason || 'Failed to add prompt';
        }
    } catch (err) {
        errorDiv.textContent = 'Network error';
    }
});

// Toggle prompt
document.querySelectorAll('.toggle-prompt').forEach(btn => {
    btn.onclick = async () => {
        const id = btn.dataset.id;
        const isActive = btn.dataset.active === 'true';

        try {
            const response = await fetch(`/websites/${websiteId}/moderation-prompts/${id}`, {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ isActive: !isActive })
            });

            if (response.ok) window.location.reload();
        } catch (err) {
            console.error('Toggle failed:', err);
        }
    };
});

// Delete prompt
document.querySelectorAll('.delete-prompt').forEach(btn => {
    btn.onclick = async () => {
        if (!confirm('Delete this prompt?')) return;

        const id = btn.dataset.id;

        try {
            const response = await fetch(`/websites/${websiteId}/moderation-prompts/${id}`, {
                method: 'DELETE'
            });

            if (response.ok) window.location.reload();
        } catch (err) {
            console.error('Delete failed:', err);
        }
    };
});

// Re-run moderation
const rerunBtn = document.getElementById('rerunBtn');
if (rerunBtn) {
    rerunBtn.onclick = async () => {
        if (!confirm('Re-run moderation on pending comments? Manually moderated comments will not be affected.')) return;

        rerunBtn.textContent = 'Processing...';
        rerunBtn.disabled = true;

        try {
            const response = await fetch(`/websites/${websiteId}/moderation-prompts/rerun`, {
                method: 'POST'
            });

            if (response.ok) {
                alert('Moderation re-run completed!');
                window.location.reload();
            } else {
                alert('Failed to re-run moderation');
            }
        } catch (err) {
            alert('Network error');
        } finally {
            rerunBtn.textContent = 'Re-run Moderation on Pending Comments';
            rerunBtn.disabled = false;
        }
    };
}

// Approve comment
document.querySelectorAll('.approve-comment').forEach(btn => {
    btn.onclick = async () => {
        const id = btn.dataset.id;

        try {
            const response = await fetch(`/websites/${websiteId}/comments/${id}/moderate`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ status: 'approved' })
            });

            if (response.ok) window.location.reload();
        } catch (err) {
            console.error('Approve failed:', err);
        }
    };
});

// Reject comment
document.querySelectorAll('.reject-comment').forEach(btn => {
    btn.onclick = async () => {
        const id = btn.dataset.id;

        try {
            const response = await fetch(`/websites/${websiteId}/comments/${id}/moderate`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ status: 'rejected' })
            });

            if (response.ok) window.location.reload();
        } catch (err) {
            console.error('Reject failed:', err);
        }
    };
});

// Filter comments
document.querySelectorAll('.filter-tab').forEach(tab => {
    tab.onclick = () => {
        // Update active tab
        document.querySelectorAll('.filter-tab').forEach(t => t.classList.remove('active'));
        tab.classList.add('active');

        const filter = tab.dataset.filter;
        const comments = document.querySelectorAll('.comment-card-detail');

        comments.forEach(comment => {
            if (filter === 'all') {
                comment.classList.remove('hidden');
            } else {
                const status = comment.dataset.status;
                if (status === filter) {
                    comment.classList.remove('hidden');
                } else {
                    comment.classList.add('hidden');
                }
            }
        });
    };
});

// Style tab
const saveStyleBtn = document.getElementById('saveStyleBtn');
if (saveStyleBtn) {
    const styleRadios = document.querySelectorAll('input[name="style"]');
    const previewFrame = document.getElementById('stylePreviewFrame');
    const styleOptions = document.querySelectorAll('.style-option');

    // Update preview when style changes
    styleRadios.forEach(radio => {
        radio.addEventListener('change', () => {
            const selectedStyle = radio.value;
            previewFrame.src = `/embed/${websiteId}?path=/preview&style=${selectedStyle}&preview=true`;

            // Update active state
            styleOptions.forEach(opt => opt.classList.remove('active'));
            radio.closest('.style-option').classList.add('active');
        });
    });

    // Save style
    saveStyleBtn.onclick = async () => {
        const selectedStyle = document.querySelector('input[name="style"]:checked').value;
        const errorDiv = document.getElementById('styleError');

        try {
            const response = await fetch(`/websites/${websiteId}/style`, {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ style: selectedStyle })
            });

            if (response.ok) {
                errorDiv.style.display = 'none';
                saveStyleBtn.textContent = 'Saved!';
                setTimeout(() => {
                    saveStyleBtn.textContent = 'Save Style';
                }, 2000);
            } else {
                const error = await response.json();
                errorDiv.textContent = error.reason || 'Failed to save style';
                errorDiv.style.display = 'block';
            }
        } catch (err) {
            errorDiv.textContent = 'Network error';
            errorDiv.style.display = 'block';
        }
    };
}

// Custom CSS editor
const saveCustomCssBtn = document.getElementById('saveCustomCssBtn');
if (saveCustomCssBtn) {
    const customCssInput = document.getElementById('customCss');
    const previewFrame = document.getElementById('stylePreviewFrame');

    // Debounce function for live preview
    let debounceTimer;
    customCssInput.addEventListener('input', () => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
            // Trigger preview reload with custom CSS
            const currentSrc = previewFrame.src;
            previewFrame.src = currentSrc;
        }, 1000);
    });

    // Save custom CSS
    saveCustomCssBtn.onclick = async () => {
        const customCss = customCssInput.value;
        const errorDiv = document.getElementById('customCssError');

        try {
            const response = await fetch(`/websites/${websiteId}/custom-css`, {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ customCss })
            });

            if (response.ok) {
                errorDiv.style.display = 'none';
                saveCustomCssBtn.textContent = 'Saved!';

                // Refresh preview
                const currentSrc = previewFrame.src;
                previewFrame.src = currentSrc;

                setTimeout(() => {
                    saveCustomCssBtn.textContent = 'Save Custom CSS';
                }, 2000);
            } else {
                const error = await response.json();
                errorDiv.textContent = error.reason || 'Failed to save custom CSS';
                errorDiv.style.display = 'block';
            }
        } catch (err) {
            errorDiv.textContent = 'Network error';
            errorDiv.style.display = 'block';
        }
    };
}
