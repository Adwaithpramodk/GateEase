// Base configuration
const API_URL = ''; // Integrated: relative paths use current domain

const App = {
    // Current application state
    state: {
        role: null,         // Student, mentor, security
        loginId: null,      // User ID
        token: null,        // JWT access token
        activeTab: 'dashboard',
        details: null,
        timeline: [],
        passes: [],
        pendingList: [],
        stats: {},
        logs: [],
        reports: []
    },

    // Initialize application
    init: async () => {
        // Load session if exists
        App.state.token = localStorage.getItem('access_token');
        App.state.role = localStorage.getItem('usertype');
        App.state.loginId = localStorage.getItem('lid');

        // Setup simple hash router
        window.addEventListener('hashchange', App.router);
        App.router();
    },

    // Hash Router
    router: async () => {
        const hash = window.location.hash || '#login';
        
        // Handle Logout
        if (hash === '#logout') {
            App.logout();
            return;
        }

        // Redirect to Login if unauthenticated
        if (!App.state.token && hash !== '#login' && hash !== '#signup') {
            window.location.hash = '#login';
            return;
        }

        // Render Login or Signup
        if (hash === '#login' || hash === '#signup') {
            const pageType = hash === '#signup' ? 'signup' : 'login';
            document.getElementById('main-content').innerHTML = Components.AuthScreen(pageType);
            App.bindAuthEvents(pageType);
            return;
        }

        // Parse path: #Role/Tab (e.g. #Student/dashboard)
        const parts = hash.substring(1).split('/');
        const role = parts[0];
        const tab = parts[1] || 'dashboard';

        // Check Role authorization
        if (role.toLowerCase() !== App.state.role.toLowerCase()) {
            window.location.hash = `#${App.state.role}/dashboard`;
            return;
        }

        App.state.activeTab = tab;

        // Render Dashboard shells
        let innerHtml = '';
        if (role === 'Student') {
            innerHtml = await App.renderStudentView(tab);
        } else if (role === 'mentor') {
            innerHtml = await App.renderMentorView(tab);
        } else if (role === 'security') {
            innerHtml = await App.renderSecurityView(tab);
        }

        document.getElementById('main-content').innerHTML = Components.DashboardShell(App.state.role, tab, innerHtml);
        App.bindDashboardEvents(role, tab);
    },

    // ── API CLIENT WRAPPER ──
    api: async (endpoint, options = {}) => {
        const headers = {
            'Content-Type': 'application/json',
            ...options.headers
        };

        if (App.state.token) {
            headers['Authorization'] = `Bearer ${App.state.token}`;
        }

        try {
            const response = await fetch(`${API_URL}${endpoint}`, {
                ...options,
                headers
            });

            if (response.status === 401) {
                // Try to refresh token
                const success = await App.refreshToken();
                if (success) {
                    headers['Authorization'] = `Bearer ${App.state.token}`;
                    return App.api(endpoint, options);
                } else {
                    App.logout();
                    throw new Error('Session expired');
                }
            }

            if (!response.ok) {
                const errorData = await response.json().catch(() => ({}));
                throw new Error(errorData.message || 'API request failed');
            }

            return await response.json();
        } catch (error) {
            console.error('API Error:', error);
            throw error;
        }
    },

    // Refresh JWT Token
    refreshToken: async () => {
        const refresh = localStorage.getItem('refresh_token');
        if (!refresh) return false;

        try {
            const res = await fetch(`${API_URL}/api/token/refresh/`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ refresh })
            });

            if (res.ok) {
                const data = await res.json();
                App.state.token = data.access;
                localStorage.setItem('access_token', data.access);
                return true;
            }
        } catch (e) {
            console.error('Failed to refresh token', e);
        }
        return false;
    },

    // Authentication Handlers
    bindAuthEvents: (type) => {
        const form = document.getElementById('auth-form');
        const submitBtn = document.getElementById('auth-submit-btn');
        if (!form) return;

        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            submitBtn.disabled = true;
            const username = document.getElementById('username').value;
            const password = document.getElementById('password').value;

            if (type === 'login') {
                try {
                    const data = await App.api('/LoginpageAPI', {
                        method: 'POST',
                        body: JSON.stringify({ username, password })
                    });
                    
                    App.state.token = data.access;
                    App.state.role = data.usertype;
                    App.state.loginId = data.login_id;

                    localStorage.setItem('access_token', data.access);
                    localStorage.setItem('refresh_token', data.refresh);
                    localStorage.setItem('usertype', data.usertype);
                    localStorage.setItem('lid', data.login_id);

                    // Mock register device token for push notification compliance
                    await App.api('/register_device_token/', {
                        method: 'POST',
                        body: JSON.stringify({ login_id: data.login_id, device_token: 'web_client_token' })
                    }).catch(() => {});

                    App.toast('Logged in successfully', 'success');
                    window.location.hash = `#${data.usertype}/dashboard`;
                } catch (err) {
                    App.toast(err.message || 'Login failed', 'error');
                }
            } else {
                const usertype = document.getElementById('usertype').value;
                try {
                    await App.api('/UserReg', {
                        method: 'POST',
                        body: JSON.stringify({ username, password, usertype })
                    });
                    App.toast('Account created! Please Sign In', 'success');
                    window.location.hash = '#login';
                } catch (err) {
                    App.toast(err.message || 'Sign up failed', 'error');
                }
            }
            submitBtn.disabled = false;
        });
    },

    // ── RENDER PROCEDURES ──
    renderStudentView: async (tab) => {
        if (tab === 'dashboard') {
            // Fetch Details and Timeline
            App.state.details = await App.api(`/StudentInfo_api/${App.state.loginId}`).catch(() => ({}));
            const timelineData = await App.api(`/ExitPassTimelineAPI/${App.state.loginId}/`).catch(() => []);
            
            App.state.timeline = Array.isArray(timelineData) ? timelineData : [];
            return Components.StudentDashboard(App.state.details, App.state.timeline);
        } else if (tab === 'new-pass') {
            return Components.NewPassForm();
        } else if (tab === 'my-passes') {
            // Fetch active passes
            const passes = await App.api(`/StudentListAPI/${App.state.loginId}`).catch(() => []);
            App.state.passes = passes.map(p => ({
                reason: p.reason,
                date: p.created_at?.split('T')[0],
                status: p.mentor_status === 'approved' && p.security_status === 'scanned' ? 'Scanned' : p.mentor_status,
                qr_data: p.id // use pass ID as simple QR data
            }));
            return Components.PassHistory(App.state.passes);
        } else if (tab === 'support') {
            return Components.SupportView();
        }
    },

    renderMentorView: async (tab) => {
        if (tab === 'dashboard') {
            // Fetch stats and pending passes
            const stats = await App.api(`/MentorDashboardStatsAPI/${App.state.loginId}`).catch(() => ({}));
            const pending = await App.api(`/Pendingpass_api/${App.state.loginId}`).catch(() => []);
            
            App.state.stats = stats;
            App.state.pendingList = pending.map(p => ({
                id: p.id,
                student_name: p.student_name,
                reason: p.reason,
                date: p.departure_time?.replace('T', ' ')
            }));
            return Components.MentorDashboard(App.state.stats, App.state.pendingList);
        } else if (tab === 'group-pass') {
            const list = await App.api(`/GroupPassAPI/${App.state.loginId}`).catch(() => []);
            return `
                <div class="header-bar">
                    <div class="dashboard-title">Group Passes</div>
                </div>
                <div class="stitch-border" style="padding: 24px; color: var(--text-sub);">
                    Currently managed group passes list.
                </div>
            `;
        } else if (tab === 'reports') {
            const history = await App.api(`/MentorExitReportAPI/${App.state.loginId}`).catch(() => []);
            App.state.reports = history.map(h => ({
                student_name: h.student_name,
                reason: h.reason,
                approved_date: h.approved_at?.split('T')[0] || 'N/A',
                status: h.status
            }));
            return Components.MentorReports(App.state.reports);
        }
    },

    renderSecurityView: async (tab) => {
        if (tab === 'dashboard') {
            const logs = await App.api(`/SecurityApprovedPassAPI/${App.state.loginId}`).catch(() => []);
            App.state.logs = logs.map(l => ({
                student_name: l.student_name,
                pass_type: l.reason,
                timestamp: l.scanned_at?.replace('T', ' ').substring(0, 19) || 'N/A'
            }));
            return Components.SecurityDashboard(App.state.logs);
        } else if (tab === 'scan-qr') {
            return `
                <div class="header-bar">
                    <div class="dashboard-title">Live QR Verification</div>
                </div>
                <div class="stitch-border" style="max-width: 600px; padding: 24px; margin: 0 auto; text-align: center;">
                    <div id="reader"></div>
                    <button onclick="App.startQRScanner()" class="btn-action" style="margin-top: 20px;">Start Video Stream</button>
                </div>
            `;
        }
    },

    // Bind Event Listeners on Dashboard elements
    bindDashboardEvents: (role, tab) => {
        if (role === 'Student' && tab === 'new-pass') {
            const form = document.getElementById('new-pass-form');
            if (form) {
                form.addEventListener('submit', async (e) => {
                    e.preventDefault();
                    const reason = document.getElementById('pass-reason').value;
                    const details = document.getElementById('pass-details').value;
                    const departure_time = document.getElementById('pass-time').value;

                    try {
                        await App.api(`/ApplypassAPI/${App.state.loginId}`, {
                            method: 'POST',
                            body: JSON.stringify({ reason, details, departure_time })
                        });
                        App.toast('Pass request submitted!', 'success');
                        window.location.hash = '#Student/dashboard';
                    } catch (err) {
                        App.toast(err.message || 'Failed to submit', 'error');
                    }
                });
            }
        } else if (role === 'Student' && tab === 'support') {
            const form = document.getElementById('complaint-form');
            if (form) {
                form.addEventListener('submit', async (e) => {
                    e.preventDefault();
                    const complaint = document.getElementById('complaint-text').value;

                    try {
                        await App.api(`/ViewcomplaintAPI/${App.state.loginId}`, {
                            method: 'POST',
                            body: JSON.stringify({ complaint })
                        });
                        App.toast('Complaint submitted successfully', 'success');
                        document.getElementById('complaint-text').value = '';
                    } catch (err) {
                        App.toast(err.message || 'Failed to submit complaint', 'error');
                    }
                });
            }
        }
    },

    // ── MENTOR ACTIONS ──
    approvePass: async (passId, isApproved) => {
        const endpoint = isApproved ? '/approve' : '/reject';
        try {
            await App.api(endpoint, {
                method: 'POST',
                body: JSON.stringify({ pass_id: passId })
            });
            App.toast(`Pass request ${isApproved ? 'Approved' : 'Rejected'}`, 'success');
            App.router();
        } catch (err) {
            App.toast(err.message || 'Action failed', 'error');
        }
    },

    // ── SECURITY ACTIONS ──
    openScanner: () => {
        window.location.hash = '#security/scan-qr';
    },

    startQRScanner: () => {
        const html5QrcodeScanner = new Html5Qrcode("reader");
        html5QrcodeScanner.start(
            { facingMode: "environment" },
            { fps: 10, qrbox: 250 },
            async (decodedText) => {
                // Success: verify pass on server
                html5QrcodeScanner.stop();
                try {
                    const result = await App.api('/CheckPassStatus', {
                        method: 'POST',
                        body: JSON.stringify({ pass_id: decodedText })
                    });
                    
                    if (result.status === 'valid') {
                        // Confirm exit
                        await App.api('/AcceptPass', {
                            method: 'POST',
                            body: JSON.stringify({ pass_id: decodedText, security_id: App.state.loginId })
                        });
                        App.toast('Pass Verified! Student Exit Approved.', 'success');
                    } else {
                        App.toast('Verification failed: Invalid Pass.', 'error');
                    }
                } catch (e) {
                    App.toast('Invalid QR code format.', 'error');
                }
                window.location.hash = '#security/dashboard';
            },
            () => { /* Errors are ignored during frame scanning */ }
        ).catch(() => App.toast('Camera stream unavailable.', 'error'));
    },

    // Modal view for student QR code
    showQRCode: (data) => {
        const modal = document.createElement('div');
        modal.id = 'qr-modal';
        modal.style = 'position: fixed; inset: 0; background: rgba(0,0,0,0.8); display: flex; align-items: center; justify-content: center; z-index: 10000;';
        modal.innerHTML = `
            <div class="stitch-border" style="background: var(--surface-dark); padding: 40px; text-align: center; max-width: 380px; width: 100%;">
                <h3>Student Exit Pass QR</h3>
                <div id="qrcode-container" style="background: white; padding: 20px; border-radius: 8px; margin: 24px auto; width: 200px; height: 200px; display: flex; align-items: center; justify-content: center;">
                    <!-- Embedded QR API from Django -->
                    <img src="${API_URL}/GenerateQRCode?text=${data}" style="width: 100%; height: 100%;">
                </div>
                <button onclick="document.getElementById('qr-modal').remove()" class="btn-action">Close</button>
            </div>
        `;
        document.body.appendChild(modal);
    },

    // UI Helper: Toast
    toast: (message, type = 'info') => {
        const container = document.getElementById('toast-container');
        if (!container) return;

        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.innerHTML = `
            <span>${message}</span>
            <button onclick="this.parentElement.remove()" style="background: none; border: none; color: inherit; cursor: pointer; font-size: 16px; font-weight: bold;">&times;</button>
        `;
        container.appendChild(toast);
        setTimeout(() => toast.remove(), 4000);
    },

    // Logout
    logout: () => {
        App.api('/delete_device_token/', {
            method: 'POST',
            body: JSON.stringify({ login_id: App.state.loginId, device_token: 'web_client_token' })
        }).catch(() => {});

        App.state.token = null;
        App.state.role = null;
        App.state.loginId = null;

        localStorage.removeItem('access_token');
        localStorage.removeItem('refresh_token');
        localStorage.removeItem('usertype');
        localStorage.removeItem('lid');

        window.location.hash = '#login';
    }
};

// Startup
document.addEventListener('DOMContentLoaded', App.init);
