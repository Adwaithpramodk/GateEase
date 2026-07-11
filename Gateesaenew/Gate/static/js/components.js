const Components = {
    // ── AUTH SCREEN templates ──
    AuthScreen: (type = 'login') => {
        const isLogin = type === 'login';
        return `
            <div class="auth-wrapper">
                <div class="auth-card stitch-border">
                    <div class="auth-header">
                        <div class="auth-brand">Gate<span>Ease</span></div>
                        <div class="auth-subtitle">${isLogin ? 'Sign in to access your dashboard' : 'Create your smart student account'}</div>
                    </div>
                    <form id="auth-form" onsubmit="event.preventDefault();">
                        <div class="form-group">
                            <label class="form-label">Username / Email</label>
                            <input type="text" id="username" class="form-control" placeholder="Enter username" required>
                        </div>
                        <div class="form-group">
                            <label class="form-label">Password</label>
                            <input type="password" id="password" class="form-control" placeholder="••••••••" required>
                        </div>
                        ${!isLogin ? `
                        <div class="form-group">
                            <label class="form-label">Account Type</label>
                            <select id="usertype" class="form-control">
                                <option value="Student">Student</option>
                                <option value="mentor">Mentor</option>
                                <option value="security">Security Guard</option>
                            </select>
                        </div>
                        ` : ''}
                        
                        <div class="form-group" style="margin-top: 24px;">
                            <label class="checkbox-container">
                                <input type="checkbox" id="privacy-check" style="width: 16px; height: 16px;" required>
                                <span>I accept the Privacy Policy</span>
                            </label>
                        </div>
                        <button type="submit" id="auth-submit-btn" class="btn-action">
                            <span>${isLogin ? 'Sign In' : 'Create Account'}</span>
                        </button>
                        <div style="text-align: center; margin-top: 20px;">
                            ${isLogin ? 
                                `Don't have an account? <a href="#signup" style="color: var(--primary-light); text-decoration: none;">Create Account</a>` :
                                `Already have an account? <a href="#login" style="color: var(--primary-light); text-decoration: none;">Sign In</a>`
                            }
                        </div>
                    </form>
                </div>
            </div>
        `;
    },

    // ── SHELL CONTAINER templates ──
    DashboardShell: (role, activeTab, innerContent) => {
        let menuItems = [];
        if (role === 'Student') {
            menuItems = [
                { id: 'dashboard', label: 'Dashboard', icon: 'dashboard' },
                { id: 'new-pass', label: 'New Pass', icon: 'add_circle' },
                { id: 'my-passes', label: 'My Passes', icon: 'confirmation_number' },
                { id: 'support', label: 'Support', icon: 'support_agent' }
            ];
        } else if (role === 'mentor') {
            menuItems = [
                { id: 'dashboard', label: 'Dashboard', icon: 'dashboard' },
                { id: 'group-pass', label: 'Group Passes', icon: 'group' },
                { id: 'reports', label: 'Reports & Audits', icon: 'description' }
            ];
        } else if (role === 'security') {
            menuItems = [
                { id: 'dashboard', label: 'Dashboard', icon: 'dashboard' },
                { id: 'scan-qr', label: 'Scan Code', icon: 'qr_code_scanner' }
            ];
        }

        const navHtml = menuItems.map(item => `
            <a href="#${role}/${item.id}" class="nav-item ${activeTab === item.id ? 'active' : ''}">
                <span class="material-icons-round">${item.icon}</span>
                <span>${item.label}</span>
            </a>
        `).join('');

        return `
            <div class="dashboard-layout">
                <aside class="sidebar">
                    <div class="auth-brand">Gate<span>Ease</span></div>
                    <nav class="nav-menu">
                        ${navHtml}
                        <a href="#logout" class="nav-item" style="margin-top: 40px; color: var(--error);">
                            <span class="material-icons-round">logout</span>
                            <span>Sign Out</span>
                        </a>
                    </nav>
                </aside>
                <main class="main-workspace">
                    ${innerContent}
                </main>
            </div>
        `;
    },

    // ── STUDENT VIEW templates ──
    StudentDashboard: (details, timeline) => {
        let timelineHtml = timeline.map(item => {
            const isCompleted = item.status === 'completed';
            const icon = isCompleted ? 'check_circle' : 'schedule';
            const statusClass = isCompleted ? 'status-completed' : 'status-pending';
            return `
                <div class="timeline-item ${statusClass}" style="display: flex; gap: 16px; margin-bottom: 20px;">
                    <div style="color: ${isCompleted ? 'var(--success)' : 'var(--text-sub)'}">
                        <span class="material-icons-round">${icon}</span>
                    </div>
                    <div>
                        <div style="font-weight: 600;">${item.title}</div>
                        <div style="font-size: 12px; color: var(--text-sub);">${item.time}</div>
                    </div>
                </div>
            `;
        }).join('');

        if (timeline.length === 0) {
            timelineHtml = `<div style="color: var(--text-sub);">No active pass timeline.</div>`;
        }

        return `
            <div class="header-bar">
                <div class="dashboard-title">Welcome back, ${details?.name || 'Student'}</div>
                <div style="font-size: 14px; color: var(--text-sub);">Department: ${details?.department || 'N/A'}</div>
            </div>
            
            <div class="stats-grid">
                <div class="stat-card stitch-border">
                    <div style="font-size: 14px; color: var(--text-sub);">Admission Number</div>
                    <div class="stat-val" style="font-size: 24px;">${details?.admission_no || 'N/A'}</div>
                </div>
                <div class="stat-card stitch-border">
                    <div style="font-size: 14px; color: var(--text-sub);">Class</div>
                    <div class="stat-val" style="font-size: 24px;">${details?.class_name || 'N/A'}</div>
                </div>
            </div>

            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 40px; margin-top: 40px;">
                <div class="stitch-border" style="padding: 28px;">
                    <h3>Quick Actions</h3>
                    <div style="display: flex; gap: 16px; margin-top: 20px;">
                        <a href="#Student/new-pass" class="btn-action" style="flex: 1; text-decoration: none;">New Pass</a>
                        <a href="#Student/my-passes" class="btn-action" style="flex: 1; text-decoration: none; background: var(--surface-card); border: 1px solid var(--border-light);">My Passes</a>
                    </div>
                </div>
                <div class="stitch-border" style="padding: 28px;">
                    <h3>Pass Progress Tracker</h3>
                    <div style="margin-top: 24px;">
                        ${timelineHtml}
                    </div>
                </div>
            </div>
        `;
    },

    NewPassForm: () => {
        return `
            <div class="header-bar">
                <div class="dashboard-title">Apply for Exit Pass</div>
            </div>
            <div class="stitch-border" style="max-width: 600px; padding: 40px 32px;">
                <form id="new-pass-form" onsubmit="event.preventDefault();">
                    <div class="form-group">
                        <label class="form-label">Reason for Leaving</label>
                        <select id="pass-reason" class="form-control" required>
                            <option value="Medical">Medical Checkup</option>
                            <option value="Home visit">Home Visit</option>
                            <option value="Official college work">Official College Work</option>
                            <option value="Other">Other</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label class="form-label">Detailed Explanation</label>
                        <textarea id="pass-details" class="form-control" rows="4" placeholder="Briefly explain the reason..." required></textarea>
                    </div>
                    <div class="form-group">
                        <label class="form-label">Departure Date & Time</label>
                        <input type="datetime-local" id="pass-time" class="form-control" required>
                    </div>
                    <button type="submit" class="btn-action" style="margin-top: 24px;">Submit Pass Request</button>
                </form>
            </div>
        `;
    },

    PassHistory: (passes) => {
        const passesHtml = passes.map(pass => `
            <tr>
                <td>${pass.reason}</td>
                <td>${pass.date || 'N/A'}</td>
                <td><span class="status-tag ${pass.status.toLowerCase()}">${pass.status}</span></td>
                <td>
                    ${pass.status === 'Approved' ? `<button onclick="App.showQRCode('${pass.qr_data}')" class="btn-action" style="padding: 8px 12px; font-size: 12px; width: auto;">Show QR</button>` : 'N/A'}
                </td>
            </tr>
        `).join('');

        return `
            <div class="header-bar">
                <div class="dashboard-title">My Exit Passes</div>
            </div>
            <div class="table-container stitch-border">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Reason</th>
                            <th>Date Requested</th>
                            <th>Status</th>
                            <th>Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${passes.length > 0 ? passesHtml : `<tr><td colspan="4" style="text-align: center; color: var(--text-sub);">No exit passes found.</td></tr>`}
                    </tbody>
                </table>
            </div>
        `;
    },

    SupportView: () => {
        return `
            <div class="header-bar">
                <div class="dashboard-title">Complaints & Support</div>
            </div>
            <div class="stitch-border" style="max-width: 600px; padding: 40px 32px;">
                <h3>File a Complaint</h3>
                <form id="complaint-form" onsubmit="event.preventDefault();" style="margin-top: 24px;">
                    <div class="form-group">
                        <label class="form-label">Describe your issue</label>
                        <textarea id="complaint-text" class="form-control" rows="6" placeholder="Explain the problem..." required></textarea>
                    </div>
                    <button type="submit" class="btn-action">Submit Complaint</button>
                </form>
            </div>
        `;
    },

    // ── MENTOR VIEW templates ──
    MentorDashboard: (stats, pendingList) => {
        const listHtml = pendingList.map(item => `
            <tr>
                <td>${item.student_name}</td>
                <td>${item.reason}</td>
                <td>${item.date}</td>
                <td>
                    <button onclick="App.approvePass(${item.id}, true)" class="btn-action" style="background: var(--success); width: auto; display: inline-flex; padding: 8px 16px; margin-right: 8px;">Approve</button>
                    <button onclick="App.approvePass(${item.id}, false)" class="btn-action" style="background: var(--error); width: auto; display: inline-flex; padding: 8px 16px;">Reject</button>
                </td>
            </tr>
        `).join('');

        return `
            <div class="header-bar">
                <div class="dashboard-title">Mentor Dashboard</div>
            </div>
            <div class="stats-grid">
                <div class="stat-card stitch-border">
                    <div style="font-size: 14px; color: var(--text-sub);">Pending Approvals</div>
                    <div class="stat-val">${stats.pending || 0}</div>
                </div>
                <div class="stat-card stitch-border">
                    <div style="font-size: 14px; color: var(--text-sub);">Approved Passes</div>
                    <div class="stat-val" style="color: var(--success);">${stats.approved || 0}</div>
                </div>
                <div class="stat-card stitch-border">
                    <div style="font-size: 14px; color: var(--text-sub);">Rejected Passes</div>
                    <div class="stat-val" style="color: var(--error);">${stats.rejected || 0}</div>
                </div>
            </div>

            <h3>Pending Student Exit Requests</h3>
            <div class="table-container stitch-border">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Student</th>
                            <th>Reason</th>
                            <th>Departure Requested</th>
                            <th>Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${pendingList.length > 0 ? listHtml : `<tr><td colspan="4" style="text-align: center; color: var(--text-sub);">No pending requests.</td></tr>`}
                    </tbody>
                </table>
            </div>
        `;
    },

    MentorReports: (history) => {
        const rowsHtml = history.map(item => `
            <tr>
                <td>${item.student_name}</td>
                <td>${item.reason}</td>
                <td>${item.approved_date}</td>
                <td><span class="status-tag ${item.status.toLowerCase()}">${item.status}</span></td>
            </tr>
        `).join('');

        return `
            <div class="header-bar">
                <div class="dashboard-title">Exit Reports & Audits</div>
            </div>
            <div class="table-container stitch-border">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Student</th>
                            <th>Reason</th>
                            <th>Approved Date</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${history.length > 0 ? rowsHtml : `<tr><td colspan="4" style="text-align: center; color: var(--text-sub);">No historical reports.</td></tr>`}
                    </tbody>
                </table>
            </div>
        `;
    },

    // ── SECURITY VIEW templates ──
    SecurityDashboard: (logs) => {
        const logsHtml = logs.map(log => `
            <tr>
                <td>${log.student_name}</td>
                <td>${log.pass_type}</td>
                <td>${log.timestamp}</td>
                <td><span class="status-tag approved">Checked Out</span></td>
            </tr>
        `).join('');

        return `
            <div class="header-bar">
                <div class="dashboard-title">Gate Security Control</div>
            </div>
            <div class="stitch-border" style="padding: 40px; text-align: center; margin-bottom: 40px;">
                <span class="material-icons-round" style="font-size: 64px; color: var(--primary-light);">qr_code_scanner</span>
                <h3 style="margin-top: 16px;">Verify Exit Gate Passes</h3>
                <p style="color: var(--text-sub); margin-top: 8px;">Scan the QR code displayed on the student's phone to check pass validity.</p>
                <button onclick="App.openScanner()" class="btn-action" style="width: auto; margin: 24px auto 0; padding: 12px 24px;">Start Camera Scanner</button>
            </div>

            <h3>Recent Activity Logs</h3>
            <div class="table-container stitch-border">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Student</th>
                            <th>Reason</th>
                            <th>Check-Out Time</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${logs.length > 0 ? logsHtml : `<tr><td colspan="4" style="text-align: center; color: var(--text-sub);">No recent gate checkout logs.</td></tr>`}
                    </tbody>
                </table>
            </div>
        `;
    }
};
