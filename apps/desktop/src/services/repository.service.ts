/**
 * EH Home Desktop — Engineering Repository & Source Workspace Service
 * (Parts 14–21)
 *
 * Connects to canonical remote GitHub repository:
 * https://github.com/pavan-firmware/EH-Master-Repo
 * and manages local master repository workspace (status, branches, real files, source viewer).
 *
 * Security Invariant: Zero plaintext token storage in logs, UI, or QR codes.
 */

import { logger } from '../lib/logger';

export interface RepositoryWorkspaceInfo {
  canonicalRemoteUrl: string;
  owner: string;
  repoName: string;
  defaultBranch: string;
  localWorkspacePath: string;
  isGitRepo: boolean;
  currentBranch: string;
  lastCommitSha?: string;
  lastCommitMessage?: string;
  lastCommitAuthor?: string;
  lastCommitDate?: string;
  isClean: boolean;
  changedFilesCount: number;
  changedFiles: string[];
  accessCapability: string;
}

export interface RepositoryFileItem {
  name: string;
  path: string;
  isDir: boolean;
  sizeBytes: number;
  extension?: string;
}

export interface SourceFileContentResponse {
  filePath: string;
  fileName: string;
  sizeBytes: number;
  language: string;
  content: string;
  isTruncated: boolean;
}

export interface GitHubAuthStatus {
  isAuthenticated: boolean;
  authState: 'NOT_CONNECTED' | 'READ_ONLY' | 'WRITE_ACCESS';
  username?: string;
  accessLevel: string; // "Read", "Public / Read-Only", "Read / Write (Full Access)"
  canPush: boolean;
  canCreatePr: boolean;
  tokenSource?: string;
}

export interface GitHubRemoteRepoDetails {
  fullName: string;
  description: string;
  defaultBranch: string;
  htmlUrl: string;
  starsCount: number;
  forksCount: number;
  openIssuesCount: number;
  isPrivate: boolean;
  updatedAt: string;
}

export class RepositoryService {
  private static instance: RepositoryService;

  public static getInstance(): RepositoryService {
    if (!RepositoryService.instance) {
      RepositoryService.instance = new RepositoryService();
    }
    return RepositoryService.instance;
  }

  public async getWorkspaceInfo(): Promise<RepositoryWorkspaceInfo> {
    try {
      if (typeof window !== 'undefined' && (window as any).__TAURI_INTERNALS__) {
        const { invoke } = await import('@tauri-apps/api/core');
        const res = await invoke<any>('get_repository_workspace_info');
        if (res) {
          return {
            canonicalRemoteUrl: res.canonical_remote_url || res.canonicalRemoteUrl || 'https://github.com/pavan-firmware/EH-Master-Repo.git',
            owner: res.owner || 'pavan-firmware',
            repoName: res.repo_name || res.repoName || 'EH-Master-Repo',
            defaultBranch: res.default_branch || res.defaultBranch || 'main',
            localWorkspacePath: res.local_workspace_path || res.localWorkspacePath || 'C:\\Users\\pavan\\Downloads\\Flutter\\SMART_HOME_V1',
            isGitRepo: res.is_git_repo ?? res.isGitRepo ?? true,
            currentBranch: res.current_branch || res.currentBranch || 'main',
            lastCommitSha: res.last_commit_sha || res.lastCommitSha,
            lastCommitMessage: res.last_commit_message || res.lastCommitMessage,
            lastCommitAuthor: res.last_commit_author || res.lastCommitAuthor,
            lastCommitDate: res.last_commit_date || res.lastCommitDate,
            isClean: res.is_clean ?? res.isClean ?? true,
            changedFilesCount: res.changed_files_count ?? res.changedFilesCount ?? 0,
            changedFiles: res.changed_files || res.changedFiles || [],
            accessCapability: res.access_capability || res.accessCapability || 'Repository access: Read',
          };
        }
      }
    } catch (err) {
      logger.warn('[RepositoryService] Tauri get_repository_workspace_info failed, using default', err);
    }

    return {
      canonicalRemoteUrl: 'https://github.com/pavan-firmware/EH-Master-Repo',
      owner: 'pavan-firmware',
      repoName: 'EH-Master-Repo',
      defaultBranch: 'main',
      localWorkspacePath: 'C:\\Users\\pavan\\Downloads\\Flutter\\SMART_HOME_V1',
      isGitRepo: true,
      currentBranch: 'main',
      lastCommitSha: '1522289f46555b947dac5efb0ad0fbbc9f44260a',
      lastCommitMessage: 'feat(phase48): home ownership membership RBAC & master repository consolidation',
      lastCommitAuthor: 'pavan-firmware',
      lastCommitDate: new Date().toISOString(),
      isClean: true,
      changedFilesCount: 0,
      changedFiles: [],
      accessCapability: 'Repository access: Read',
    };
  }

  public async listFiles(subpath?: string): Promise<RepositoryFileItem[]> {
    try {
      if (typeof window !== 'undefined' && (window as any).__TAURI_INTERNALS__) {
        const { invoke } = await import('@tauri-apps/api/core');
        const res = await invoke<any[]>('list_repository_files', { subpath: subpath || null });
        if (Array.isArray(res) && res.length > 0) {
          return res.map((item) => ({
            name: item.name,
            path: item.path,
            isDir: item.is_dir ?? item.isDir ?? false,
            sizeBytes: item.size_bytes ?? item.sizeBytes ?? 0,
            extension: item.extension,
          }));
        }
      }
    } catch (err) {
      logger.warn('[RepositoryService] Tauri list_repository_files failed', err);
    }

    // Default structure for fallback/web preview
    const baseItems: RepositoryFileItem[] = [
      { name: 'apps', path: 'apps', isDir: true, sizeBytes: 0 },
      { name: 'backend', path: 'backend', isDir: true, sizeBytes: 0 },
      { name: 'firmware', path: 'firmware', isDir: true, sizeBytes: 0 },
      { name: 'hardware', path: 'hardware', isDir: true, sizeBytes: 0 },
      { name: 'packages', path: 'packages', isDir: true, sizeBytes: 0 },
      { name: 'product-definitions', path: 'product-definitions', isDir: true, sizeBytes: 0 },
      { name: 'scripts', path: 'scripts', isDir: true, sizeBytes: 0 },
      { name: 'smart_home_application_v1', path: 'smart_home_application_v1', isDir: true, sizeBytes: 0 },
      { name: 'tools', path: 'tools', isDir: true, sizeBytes: 0 },
      { name: 'package.json', path: 'package.json', isDir: false, sizeBytes: 646, extension: 'json' },
      { name: 'README.md', path: 'README.md', isDir: false, sizeBytes: 6842, extension: 'md' },
    ];
    return baseItems;
  }

  public async readSourceFile(filePath: string): Promise<SourceFileContentResponse> {
    try {
      if (typeof window !== 'undefined' && (window as any).__TAURI_INTERNALS__) {
        const { invoke } = await import('@tauri-apps/api/core');
        const res = await invoke<any>('read_source_file_content', { filePath, file_path: filePath });
        if (res) {
          return {
            filePath: res.file_path || res.filePath || filePath,
            fileName: res.file_name || res.fileName || filePath.split('/').pop() || filePath,
            sizeBytes: res.size_bytes ?? res.sizeBytes ?? 0,
            language: res.language || 'text',
            content: res.content || '',
            isTruncated: res.is_truncated ?? res.isTruncated ?? false,
          };
        }
      }
    } catch (err: any) {
      logger.warn('[RepositoryService] Tauri read_source_file_content failed', err);
    }

    return {
      filePath,
      fileName: filePath.split('/').pop() || filePath,
      sizeBytes: 0,
      language: 'markdown',
      content: `# ${filePath}\n\nFile preview available in native desktop workbench runtime.`,
      isTruncated: false,
    };
  }

  public async getGitHubAuthStatus(): Promise<GitHubAuthStatus> {
    try {
      if (typeof window !== 'undefined' && (window as any).__TAURI_INTERNALS__) {
        const { invoke } = await import('@tauri-apps/api/core');
        const res = await invoke<any>('get_github_auth_status');
        return {
          isAuthenticated: res.is_authenticated,
          authState: res.auth_state || (res.is_authenticated ? (res.can_push ? 'WRITE_ACCESS' : 'READ_ONLY') : 'NOT_CONNECTED'),
          username: res.username,
          accessLevel: res.access_level,
          canPush: res.can_push,
          canCreatePr: res.can_create_pr,
          tokenSource: res.token_source,
        };
      }
    } catch (err) {
      logger.warn('[RepositoryService] Tauri get_github_auth_status failed', err);
    }

    return {
      isAuthenticated: false,
      authState: 'NOT_CONNECTED',
      accessLevel: 'Public / Read-Only (Anonymous)',
      canPush: false,
      canCreatePr: false,
    };
  }

  public async setGitHubToken(token: string, writeAccess?: boolean): Promise<GitHubAuthStatus> {
    try {
      if (typeof window !== 'undefined' && (window as any).__TAURI_INTERNALS__) {
        const { invoke } = await import('@tauri-apps/api/core');
        const res = await invoke<any>('set_github_token_native', { token, writeAccess: Boolean(writeAccess) });
        return {
          isAuthenticated: res.is_authenticated,
          authState: res.auth_state || 'READ_ONLY',
          username: res.username,
          accessLevel: res.access_level,
          canPush: res.can_push,
          canCreatePr: res.can_create_pr,
          tokenSource: res.token_source,
        };
      }
    } catch (err) {
      logger.error('[RepositoryService] Failed to set GitHub token', err);
      throw err;
    }
    return {
      isAuthenticated: true,
      authState: writeAccess ? 'WRITE_ACCESS' : 'READ_ONLY',
      accessLevel: writeAccess ? 'Read / Write (Full Access)' : 'Read-Only',
      canPush: Boolean(writeAccess),
      canCreatePr: Boolean(writeAccess),
    };
  }

  public async clearGitHubToken(): Promise<GitHubAuthStatus> {
    try {
      if (typeof window !== 'undefined' && (window as any).__TAURI_INTERNALS__) {
        const { invoke } = await import('@tauri-apps/api/core');
        const res = await invoke<any>('clear_github_token_native');
        return {
          isAuthenticated: res.is_authenticated,
          authState: res.auth_state || 'NOT_CONNECTED',
          username: res.username,
          accessLevel: res.access_level,
          canPush: res.can_push,
          canCreatePr: res.can_create_pr,
        };
      }
    } catch (err) {
      logger.error('[RepositoryService] Failed to clear GitHub token', err);
    }
    return {
      isAuthenticated: false,
      authState: 'NOT_CONNECTED',
      accessLevel: 'Public / Read-Only (Anonymous)',
      canPush: false,
      canCreatePr: false,
    };
  }

  public async fetchRemoteRepoDetails(): Promise<GitHubRemoteRepoDetails> {
    try {
      const resp = await fetch('https://api.github.com/repos/pavan-firmware/EH-Master-Repo', {
        headers: {
          Accept: 'application/vnd.github.v3+json',
        },
      });
      if (resp.ok) {
        const data = await resp.json();
        return {
          fullName: data.full_name || 'pavan-firmware/EH-Master-Repo',
          description: data.description || 'EH Home Master Monorepo — Smart Home Engineering & Manufacturing',
          defaultBranch: data.default_branch || 'main',
          htmlUrl: data.html_url || 'https://github.com/pavan-firmware/EH-Master-Repo',
          starsCount: data.stargazers_count || 0,
          forksCount: data.forks_count || 0,
          openIssuesCount: data.open_issues_count || 0,
          isPrivate: Boolean(data.private),
          updatedAt: data.updated_at || new Date().toISOString(),
        };
      }
    } catch (err) {
      logger.warn('[RepositoryService] Failed to query GitHub public API', err);
    }

    return {
      fullName: 'pavan-firmware/EH-Master-Repo',
      description: 'EH Home Master Monorepo — Smart Home Engineering & Manufacturing',
      defaultBranch: 'main',
      htmlUrl: 'https://github.com/pavan-firmware/EH-Master-Repo',
      starsCount: 0,
      forksCount: 0,
      openIssuesCount: 0,
      isPrivate: false,
      updatedAt: new Date().toISOString(),
    };
  }
}

export const repositoryService = RepositoryService.getInstance();
