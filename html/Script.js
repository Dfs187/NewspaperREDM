// Script.js (Please be Server-Ready)
document.addEventListener('DOMContentLoaded', () => {
    // --- ELEMENT SELECTORS ---
    const newspaper = document.getElementById('newspaper');
    const leftPageContent = document.getElementById('left-page-content');
    const rightPageContent = document.getElementById('right-page-content');
    const prevPageBtn = document.getElementById('prev-page-btn');
    const nextPageBtn = document.getElementById('next-page-btn');
    const homeBtn = document.getElementById('home-btn');
    const articleModal = document.getElementById('article-modal');
    const closeModalBtn = document.querySelector('.close-modal-btn');

    // --- STATE ---
    let pages = [];
    let currentPageIndex = 0;
    let articlesData = [];

    // --- CONFIGURATION ---
    const categoryPageLayouts = {
        'latest_news': { title: "Latest News" },
        'community_activities': { title: "Community Activities" },
        'business_bulletin': { title: "Business Bulletins" },
        'crime': { title: "Crime Reports" },
        'wanted': { title: "WANTED" },
        'opinion': { title: "Opinion & Editorial" },
        'misc': { title: "Miscellaneous" },
        'private_sales': { title: "Private Sales" }
    };
    const mainPageCategories = ['latest_news', 'community_activities', 'business_bulletin', 'crime', 'opinion', 'private_sales', 'misc'];

    // --- CORE FUNCTIONS ---
    function buildPages(issueData) {
        pages = [];
        articlesData = issueData.articles || [];
        const adsData = issueData.advertisements || [];
        let adCounter = 0;
        const hasWantedPosters = articlesData.some(article => article.type === 'wanted');

        // Page 0: Title Page
        let titlePageContent = `
            <div class="newspaper-header">
                <div class="title">${issueData.header.title || 'The New Dawn Gazette'}</div>
                <div class="sub-header">
                    <span>${issueData.header.volume || 'VOL. 001'}</span>
                    <span>${issueData.header.date || 'Date Unknown'}</span>
                    <span>${issueData.header.number || 'NO. 1'}</span>
                </div>
            </div>
            <div class="contents-links">
                ${mainPageCategories.map(key => {
                    if (categoryPageLayouts[key]) {
                        return `<div class="nav-btn" data-category="${key}">${categoryPageLayouts[key].title}</div>`;
                    }
                    return '';
                }).join('')}
            </div>
        `;
        pages.push({ content: titlePageContent });
        
        // Group articles by their category
        const articlesByCategory = {};
        articlesData.forEach((article, index) => {
            article.originalIndex = index;
            if (categoryPageLayouts[article.type]) {
                if (!articlesByCategory[article.type]) {
                    articlesByCategory[article.type] = [];
                }
                articlesByCategory[article.type].push(article);
            }
        });

        // Build the pages for each category
        for (const category in articlesByCategory) {
            const layout = categoryPageLayouts[category];
            const categoryArticles = articlesByCategory[category];
            let articleIndex = 0;
            let isFirstPageOfCategory = true;
            
            while (articleIndex < categoryArticles.length) {
                let pageHtml = `<div class="page-title">${layout.title}</div>`;
                for (let i = 0; i < 3; i++) {
                    if (articleIndex < categoryArticles.length) {
                        const article = categoryArticles[articleIndex];
                        if (article.type === 'wanted') {
                            pageHtml += `<div class="article-box wanted-poster-box" data-index="${article.originalIndex}"><img src="https://i.ibb.co/k2cQYy1/generic-wanted-poster.png" alt="Wanted Poster"><h3>${article.title}</h3></div>`;
                        } else {
                            pageHtml += `<div class="article-box" data-index="${article.originalIndex}"><h3>${article.title}</h3><p>${article.content.substring(0, 100)}...</p></div>`;
                        }
                        articleIndex++;
                    } else {
                        pageHtml += '<div></div>'; // Empty grid slot
                    }
                }

                // Add the 4th item: either a "Wanted" button or an ad
                if (category === 'crime' && isFirstPageOfCategory && hasWantedPosters) {
                    pageHtml += `<div class="wanted-button" data-category="wanted">View<br>Wanted Posters</div>`;
                } else if (adsData.length > 0) {
                    const ad = adsData[adCounter % adsData.length];
                    pageHtml += `<div class="ad-box"><img src="${ad.image}" alt="${ad.title}"></div>`;
                    adCounter++;
                } else {
                    pageHtml += `<div></div>`; // Empty grid slot
                }
                
                pages.push({ content: pageHtml, category: category });
                isFirstPageOfCategory = false;
            }
        }
    }

    function displayCurrentSpread() {
        // Left Page
        leftPageContent.className = 'page-content';
        const leftPageIndex = currentPageIndex;
        if (pages[leftPageIndex]) {
            leftPageContent.innerHTML = pages[leftPageIndex].content;
            if (leftPageIndex === 0) leftPageContent.classList.add('title-page-container');
        } else {
            leftPageContent.innerHTML = '';
        }

        // Right Page
        rightPageContent.className = 'page-content';
        const rightPageIndex = currentPageIndex + 1;
        if (pages[rightPageIndex]) {
            rightPageContent.innerHTML = pages[rightPageIndex].content;
        } else {
            rightPageContent.innerHTML = '';
        }
        updateNavButtons();
    }

    function updateNavButtons() {
        prevPageBtn.style.display = currentPageIndex > 0 ? 'block' : 'none';
        homeBtn.style.display = currentPageIndex > 0 ? 'block' : 'none';
        nextPageBtn.style.display = (currentPageIndex === 0 && pages.length > 1) || (currentPageIndex > 0 && currentPageIndex + 2 < pages.length) ? 'block' : 'none';
    }

    function showArticle(index) {
        const article = articlesData[index];
        if (!article) return;
        document.getElementById('modal-title').textContent = article.title;
        document.getElementById('modal-text').textContent = article.content;
        document.getElementById('modal-author').textContent = `- ${article.author}`;
        const modalImage = document.getElementById('modal-image');
        
        modalImage.style.display = article.image ? 'block' : 'none';
        if (article.image) modalImage.src = article.image;

        articleModal.classList.remove('modal-hidden');
    }

    function hideArticle() {
        articleModal.classList.add('modal-hidden');
    }

    // --- MAIN NUI LISTENER ---
    window.addEventListener('message', (event) => {
        let data;
        try {
            data = JSON.parse(event.data);
        } catch(e) {
            data = event.data;
        }

        if(data.type === 'showPublicUI' && data.issueData) {
            newspaper.style.display = 'flex';
            buildPages(data.issueData);
            currentPageIndex = 0;
            displayCurrentSpread();
        }
    });

    // --- EVENT LISTENERS for navigation and clicks ---
    prevPageBtn.addEventListener('click', () => {
        let decrement = (currentPageIndex === 1) ? 1 : 2;
        if (currentPageIndex - decrement >= 0) {
            currentPageIndex -= decrement;
            displayCurrentSpread();
        }
    });
    nextPageBtn.addEventListener('click', () => {
        let increment = (currentPageIndex === 0) ? 1 : 2;
        if ((currentPageIndex === 0 && pages.length > 1) || (currentPageIndex > 0 && currentPageIndex + increment < pages.length)) {
            currentPageIndex += increment;
            displayCurrentSpread();
        }
    });
    homeBtn.addEventListener('click', () => {
        currentPageIndex = 0;
        displayCurrentSpread();
    });
    
    newspaper.addEventListener('click', (e) => {
        const articleBox = e.target.closest('.article-box');
        if (articleBox) {
            showArticle(parseInt(articleBox.dataset.index));
        }

        const navBtn = e.target.closest('.nav-btn, .wanted-button');
        if (navBtn) {
            const category = navBtn.dataset.category;
            const firstPageOfCategory = pages.findIndex(p => p.category === category);
            if (firstPageOfCategory > 0) {
                currentPageIndex = (firstPageOfCategory % 2 === 0) ? firstPageOfCategory - 1 : firstPageOfCategory;
                if(currentPageIndex === 0) currentPageIndex = 1;
                displayCurrentSpread();
            }
        }
    });

    closeModalBtn.addEventListener('click', hideArticle);
    articleModal.addEventListener('click', e => {
        if (e.target === articleModal) hideArticle();
    });
    
    document.addEventListener('keydown', e => {
        if (e.key === 'Escape') {
            if (!articleModal.classList.contains('modal-hidden')) {
                hideArticle();
            } else {
                newspaper.style.display = 'none';
                fetch(`https://newspaper/closeUI`, { method: 'POST' }).catch(err => {});
            }
        }
    });
});