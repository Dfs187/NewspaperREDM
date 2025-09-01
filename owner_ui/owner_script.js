// owner_script.js (Fixed Resource Name Version)

function closeUI() {
    document.getElementById('dashboard-container').style.display = 'none';
    fetch(`https://newspaper/closeUI`, { method: 'POST' }); // Fixed resource name
}

window.addEventListener('message', (event) => {
    let data;
    try {
        data = JSON.parse(event.data);
    } catch (e) {
        data = event.data;
    }

    if (data.type === 'owner_ui') {
        document.getElementById('dashboard-container').style.display = 'flex';
        fetchSubmissions();
    }
});

function fetchSubmissions() {
    fetch(`https://newspaper/getPendingSubmissions`, { // Fixed resource name
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    })
    .then(resp => {
        if (!resp.ok) throw new Error('Network response was not ok');
        return resp.json();
    })
    .then(displaySubmissions)
    .catch(error => {
        console.error('Error fetching submissions:', error);
        displaySubmissions([]);
    });
}

function displaySubmissions(submissions) {
    const container = document.getElementById('submissions-list');
    const noSubmissionsMsg = document.getElementById('no-submissions-message');
    container.innerHTML = '';

    if (!submissions || submissions.length === 0) {
        noSubmissionsMsg.style.display = 'block';
    } else {
        noSubmissionsMsg.style.display = 'none';
        submissions.forEach((sub, index) => {
            const card = document.createElement('div');
            card.className = 'submission-card';
            
            // Enhanced display with type and timestamp if available
            const submissionType = sub.type ? sub.type.replace(/_/g, ' ').toUpperCase() : 'UNKNOWN';
            const timestamp = sub.timestamp ? new Date(sub.timestamp * 1000).toLocaleString() : '';
            
            card.innerHTML = `
                <div class="submission-header">
                    <h3>${sub.title || 'No Title'}</h3>
                    <span class="submission-type">[${submissionType}]</span>
                </div>
                <p class="submission-author">By: ${sub.author || 'Unknown Author'}</p>
                ${timestamp ? `<p class="submission-time">${timestamp}</p>` : ''}
                <div class="submission-preview">${(sub.content || '').substring(0, 100)}${sub.content && sub.content.length > 100 ? '...' : ''}</div>
                <div class="submission-actions">
                    <button class="approve">Approve</button>
                    <button class="reject">Reject</button>
                </div>
            `;
            
            card.querySelector('.approve').addEventListener('click', () => sendAction('approve', index + 1));
            card.querySelector('.reject').addEventListener('click', () => sendAction('reject', index + 1));
            
            container.appendChild(card);
        });
    }
}

function sendAction(action, index) {
    fetch(`https://newspaper/${action}Submission`, { // Fixed resource name
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ index: index })
    })
    .then(resp => {
        if (!resp.ok) throw new Error('Network response was not ok');
        return resp.json();
    })
    .then(fetchSubmissions)
    .catch(error => {
        alert('Error with submission action: ' + (error.message || error));
        fetchSubmissions(); // Refresh anyway
    });
}

document.getElementById('closeButton').addEventListener('click', closeUI);

document.getElementById('publishButton').addEventListener('click', () => {
    const headerDetails = {
        date: document.getElementById('issue-date').value || 'Unknown Date',
        volume: document.getElementById('issue-volume').value || 'VOL. 001',
        number: document.getElementById('issue-number').value || 'NO. 1',
        title: 'The New Dawn Gazette'
    };
    fetch(`https://newspaper/publishNewspaper`, { // Fixed resource name
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ headerDetails: headerDetails })
    })
    .then(resp => resp.json())
    .then(result => {
        if (result.ok) {
            alert('Newspaper published successfully!');
            // Clear the form fields
            document.getElementById('issue-date').value = '';
            document.getElementById('issue-volume').value = '';
            document.getElementById('issue-number').value = '';
            fetchSubmissions(); // Refresh to show cleared approved submissions
        }
    })
    .catch(error => console.error('Error publishing newspaper:', error));
});

document.getElementById('writeArticleButton').addEventListener('click', () => {
    fetch(`https://newspaper/writeMyOwnArticle`, { // Fixed resource name
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
});

document.getElementById('savePricesButton').addEventListener('click', () => {
    const prices = {
        // ...populate prices as needed...
    };
    // ...save prices logic...
});
